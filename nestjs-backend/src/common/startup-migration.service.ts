import { Injectable, OnApplicationBootstrap, Logger } from '@nestjs/common';
import { DataSource } from 'typeorm';
import * as mysql2 from 'mysql2/promise';

/**
 * Runs safe ALTER TABLE statements on startup to add missing columns.
 * MySQL ignores duplicate column additions, and we catch errors gracefully.
 */
@Injectable()
export class StartupMigrationService implements OnApplicationBootstrap {
  private readonly logger = new Logger('StartupMigration');

  constructor(private readonly dataSource: DataSource) {}

  async onApplicationBootstrap() {
    // Skip for SQLite (synchronize handles it)
    if (this.dataSource.options.type === 'better-sqlite3') return;

    // Run all migrations in background so the app can start serving
    // immediately — Railway healthcheck needs /api/health to respond
    // before the 5-minute timeout. Heavy operations (old DB sync, dedup)
    // must NOT block app.listen().
    this.runMigrations().catch((err) =>
      this.logger.error(`Background migration failed: ${err.message}`, err.stack),
    );
  }

  private async runMigrations() {

    const migrations: string[] = [
      `ALTER TABLE client ADD COLUMN auto_training_notify TINYINT(1) NOT NULL DEFAULT 0`,
      `ALTER TABLE feedback ADD COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP`,
      `ALTER TABLE feedback ADD COLUMN sender_type VARCHAR(10) DEFAULT NULL`,
      // Credit tracking + cancellation columns on training
      `ALTER TABLE training ADD COLUMN credit_pack_id INT DEFAULT NULL`,
      `ALTER TABLE training ADD COLUMN credits_charged INT DEFAULT NULL`,
      `ALTER TABLE training ADD COLUMN cancelled_at DATETIME DEFAULT NULL`,
      `ALTER TABLE training ADD COLUMN cancelled_by_client_rel INT DEFAULT NULL`,
      `ALTER TABLE training ADD COLUMN cancelled_by_trainer_rel INT DEFAULT NULL`,
      // Allow exercises without a group (nullable FK)
      `ALTER TABLE exercise MODIFY COLUMN group_id INT DEFAULT NULL`,
      // Exercise anatomical metadata (for AI plan selection)
      `ALTER TABLE exercise ADD COLUMN body_region VARCHAR(20) DEFAULT NULL`,
      `ALTER TABLE exercise ADD COLUMN primary_muscle_group VARCHAR(50) DEFAULT NULL`,
      `ALTER TABLE exercise ADD COLUMN target_joint VARCHAR(30) DEFAULT NULL`,
      `ALTER TABLE exercise ADD COLUMN movement_pattern VARCHAR(20) DEFAULT NULL`,
      // Location buffer for 3-tier dynamic buffer system
      `ALTER TABLE location ADD COLUMN buffer_minutes INT DEFAULT 30`,
      // Allow null for purchase without specific training type
      `ALTER TABLE client_credits MODIFY COLUMN training_type_id INT DEFAULT NULL`,
      `ALTER TABLE client_credits MODIFY COLUMN abbonement_id INT DEFAULT NULL`,
      `ALTER TABLE client_credits MODIFY COLUMN sold_by_id INT DEFAULT NULL`,
      // Saferpay payment integration columns on invoice
      `ALTER TABLE invoice ADD COLUMN saferpay_token VARCHAR(100) DEFAULT NULL`,
      `ALTER TABLE invoice ADD COLUMN paid_at DATETIME DEFAULT NULL`,
      `ALTER TABLE invoice ADD COLUMN payment_method VARCHAR(50) DEFAULT NULL`,
      // Per-exercise comment key on training_plan_comment
      `ALTER TABLE training_plan_comment ADD COLUMN exercise_key VARCHAR(10) DEFAULT NULL`,
    ];

    // Create training_plan_comment table if not exists
    try {
      await this.dataSource.query(`
        CREATE TABLE IF NOT EXISTS training_plan_comment (
          id INT AUTO_INCREMENT PRIMARY KEY,
          plan_id INT NOT NULL,
          trainer_id INT DEFAULT NULL,
          text TEXT NOT NULL,
          author_name VARCHAR(100) DEFAULT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_tpc_plan (plan_id),
          CONSTRAINT fk_tpc_plan FOREIGN KEY (plan_id) REFERENCES trainingplan(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
      `);
      this.logger.log('training_plan_comment table ready');
    } catch (err: any) {
      if (!err.message?.includes('already exists')) {
        this.logger.warn(`training_plan_comment table: ${err.message}`);
      }
    }

    // Ensure preference table has correct schema (key/value columns)
    // Old PHP table may exist with different columns, so check and migrate
    try {
      const [cols]: any = await this.dataSource.query(
        `SELECT COUNT(*) as cnt FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = 'preference' AND column_name = 'key'`,
      );
      if (!cols || cols.cnt === 0) {
        // Table missing or has wrong schema — recreate
        await this.dataSource.query(`DROP TABLE IF EXISTS preference`);
        await this.dataSource.query(`
          CREATE TABLE preference (
            id INT AUTO_INCREMENT PRIMARY KEY,
            client_id INT NOT NULL,
            \`key\` VARCHAR(50) DEFAULT NULL,
            \`value\` VARCHAR(255) DEFAULT NULL,
            INDEX idx_pref_client (client_id),
            UNIQUE KEY uk_client_key (client_id, \`key\`)
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        `);
        this.logger.log('preference table created (fresh)');
      } else {
        this.logger.log('preference table already has correct schema');
      }
    } catch (err: any) {
      this.logger.warn(`preference table setup: ${err.message}`);
    }

    // Create push_subscription table if it doesn't exist
    const createTableSql = `
      CREATE TABLE IF NOT EXISTS push_subscription (
        id INT AUTO_INCREMENT PRIMARY KEY,
        client_id INT NOT NULL,
        endpoint TEXT NOT NULL,
        p256dh TEXT NOT NULL,
        auth TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_push_client (client_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `;
    try {
      await this.dataSource.query(createTableSql);
      this.logger.log('push_subscription table ready');
    } catch (err: any) {
      this.logger.warn(`push_subscription table creation: ${err.message}`);
    }

    // Create invoice table
    try {
      await this.dataSource.query(`
        CREATE TABLE IF NOT EXISTS invoice (
          id INT AUTO_INCREMENT PRIMARY KEY,
          invoice_number VARCHAR(20) NOT NULL UNIQUE,
          client_id INT NOT NULL,
          package_name VARCHAR(100) NOT NULL,
          amount DECIMAL(10,2) NOT NULL,
          credits INT NOT NULL DEFAULT 0,
          duration_months INT DEFAULT NULL,
          status VARCHAR(20) DEFAULT 'pending',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_invoice_client (client_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
      `);
      this.logger.log('invoice table ready');
    } catch (err: any) {
      this.logger.warn(`invoice table creation: ${err.message}`);
    }

    // ── Garmin integration tables ─────────────────────────────────────
    const garminTables = [
      `CREATE TABLE IF NOT EXISTS garmin_connection (
        id INT AUTO_INCREMENT PRIMARY KEY,
        client_id INT NOT NULL,
        access_token TEXT NOT NULL,
        access_token_secret TEXT NOT NULL,
        garmin_user_id VARCHAR(255) DEFAULT NULL,
        garmin_display_name VARCHAR(255) DEFAULT NULL,
        connected_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_sync_at DATETIME DEFAULT NULL,
        UNIQUE KEY idx_garmin_conn_client (client_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
      `CREATE TABLE IF NOT EXISTS garmin_activity (
        id INT AUTO_INCREMENT PRIMARY KEY,
        client_id INT NOT NULL,
        garmin_activity_id BIGINT NOT NULL,
        garmin_user_token VARCHAR(255) DEFAULT NULL,
        activity_type VARCHAR(100) DEFAULT NULL,
        activity_name VARCHAR(255) DEFAULT NULL,
        start_time VARCHAR(50) DEFAULT NULL,
        duration_seconds FLOAT DEFAULT NULL,
        distance_meters FLOAT DEFAULT NULL,
        active_kcal FLOAT DEFAULT NULL,
        avg_heart_rate FLOAT DEFAULT NULL,
        max_heart_rate FLOAT DEFAULT NULL,
        avg_speed FLOAT DEFAULT NULL,
        steps INT DEFAULT NULL,
        raw_json LONGTEXT,
        received_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY idx_garmin_act_id (garmin_activity_id),
        INDEX idx_garmin_act_client (client_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
      `CREATE TABLE IF NOT EXISTS garmin_daily_summary (
        id INT AUTO_INCREMENT PRIMARY KEY,
        client_id INT NOT NULL,
        calendar_date VARCHAR(10) NOT NULL,
        steps INT DEFAULT NULL,
        active_kcal FLOAT DEFAULT NULL,
        resting_heart_rate FLOAT DEFAULT NULL,
        max_heart_rate FLOAT DEFAULT NULL,
        avg_stress FLOAT DEFAULT NULL,
        body_battery_max INT DEFAULT NULL,
        body_battery_min INT DEFAULT NULL,
        sleep_duration_seconds INT DEFAULT NULL,
        sleep_score INT DEFAULT NULL,
        spo2_avg FLOAT DEFAULT NULL,
        respiration_avg FLOAT DEFAULT NULL,
        floors_climbed INT DEFAULT NULL,
        intensity_minutes INT DEFAULT NULL,
        raw_json LONGTEXT,
        received_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY idx_garmin_daily_client_date (client_id, calendar_date),
        INDEX idx_garmin_daily_client (client_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    ];
    for (const sql of garminTables) {
      try {
        await this.dataSource.query(sql);
        this.logger.log(`Garmin table ready: ${sql.substring(30, 70)}...`);
      } catch (err: any) {
        this.logger.warn(`Garmin table: ${err.message}`);
      }
    }

    for (const sql of migrations) {
      try {
        await this.dataSource.query(sql);
        this.logger.log(`Migration OK: ${sql.substring(0, 60)}...`);
      } catch (err: any) {
        // Error 1060 = "Duplicate column name" → column already exists, skip
        if (err?.errno === 1060 || err?.message?.includes('Duplicate column')) {
          this.logger.log(`Column already exists, skipping: ${sql.substring(0, 60)}...`);
        } else {
          this.logger.warn(`Migration failed: ${err.message}`);
        }
      }
    }

    // Rename exercise groups + migrate Shoulder/Spine/Legs to body regions
    // Must run AFTER column migrations (body_region column needs to exist)
    await this.migrateExerciseGroups();

    // Ensure correct locations with buffer_minutes values
    await this.ensureLocations();

    // Ensure credit packages from website pricing
    await this.ensureCreditPackages();

    // Sync trainer-client assignments from old PHP database
    await this.syncTrainerClients();

    // Copy missing file records from old PHP database
    await this.copyMissingFiles();
  }

  /**
   * Ensures the 4 production locations exist with correct buffer_minutes.
   * Deactivates old/unused locations and creates missing ones.
   *
   * Locations:
   *  1. Sportanlage Sihlhölzli  → 30 min buffer (between different locations)
   *  2. Sportanlage Allmend Brunau → 30 min buffer
   *  3. Rieterpark → 30 min buffer
   *  4. Andere → 60 min buffer (external / unknown location)
   */
  private async ensureLocations() {
    const targetLocations = [
      { name: 'Sportanlage Sihlhölzli', buffer_minutes: 30 },
      { name: 'Sportanlage Allmend Brunau', buffer_minutes: 30 },
      { name: 'Rieterpark', buffer_minutes: 30 },
      { name: 'Andere', buffer_minutes: 60 },
    ];

    try {
      for (const loc of targetLocations) {
        // Check if location already exists (by name)
        const [existing]: any = await this.dataSource.query(
          'SELECT id, buffer_minutes, active FROM location WHERE name = ?',
          [loc.name],
        );

        if (existing) {
          // Update buffer_minutes and ensure active
          await this.dataSource.query(
            'UPDATE location SET buffer_minutes = ?, active = 1 WHERE id = ?',
            [loc.buffer_minutes, existing.id],
          );
          this.logger.log(`Location "${loc.name}" updated (buffer=${loc.buffer_minutes})`);
        } else {
          // Create new location
          await this.dataSource.query(
            'INSERT INTO location (name, buffer_minutes, active) VALUES (?, ?, 1)',
            [loc.name, loc.buffer_minutes],
          );
          this.logger.log(`Location "${loc.name}" created (buffer=${loc.buffer_minutes})`);
        }
      }

      // Deactivate old locations not in the target list
      const targetNames = targetLocations.map(l => l.name);
      const placeholders = targetNames.map(() => '?').join(', ');
      await this.dataSource.query(
        `UPDATE location SET active = 0 WHERE name NOT IN (${placeholders}) AND active = 1`,
        targetNames,
      );

      // Fix orphaned records pointing to inactive locations → redirect to Sihlhölzli
      const [firstActive]: any = await this.dataSource.query(
        `SELECT id FROM location WHERE name = 'Sportanlage Sihlhölzli' AND active = 1 LIMIT 1`,
      );
      if (firstActive) {
        const activeIds = await this.dataSource.query(
          `SELECT id FROM location WHERE active = 1`,
        );
        const activeIdSet = activeIds.map((r: any) => r.id);
        if (activeIdSet.length > 0) {
          const ph = activeIdSet.map(() => '?').join(', ');
          // Fix trainer_availability
          const availResult: any = await this.dataSource.query(
            `UPDATE trainer_availability SET location_id = ? WHERE location_id IS NOT NULL AND location_id NOT IN (${ph})`,
            [firstActive.id, ...activeIdSet],
          );
          if (availResult?.affectedRows > 0) {
            this.logger.log(`Redirected ${availResult.affectedRows} availability records to Sportanlage Sihlhölzli`);
          }
          // Fix training (bookings) table
          try {
            const bookResult: any = await this.dataSource.query(
              `UPDATE training SET location_id = ? WHERE location_id IS NOT NULL AND location_id NOT IN (${ph})`,
              [firstActive.id, ...activeIdSet],
            );
            if (bookResult?.affectedRows > 0) {
              this.logger.log(`Redirected ${bookResult.affectedRows} booking records to Sportanlage Sihlhölzli`);
            }
          } catch (err: any) {
            this.logger.warn(`Booking location fix: ${err.message}`);
          }
        }
      }

      // Deduplicate availability: keep only MIN(id) per (trainer, date, from, to, location)
      try {
        // Step 1: Find IDs to keep (smallest id per unique combo)
        const keepRows: any[] = await this.dataSource.query(`
          SELECT MIN(id) as keep_id
          FROM trainer_availability
          GROUP BY trainer_id, date, location_id, \`from\`, \`to\`
        `);
        const keepIds = keepRows.map((r: any) => r.keep_id).filter(Boolean);
        if (keepIds.length > 0) {
          const keepPh = keepIds.map(() => '?').join(', ');
          const dedupResult: any = await this.dataSource.query(
            `DELETE FROM trainer_availability WHERE id NOT IN (${keepPh})`,
            keepIds,
          );
          if (dedupResult?.affectedRows > 0) {
            this.logger.log(`Removed ${dedupResult.affectedRows} duplicate availability records`);
          }
        }

        // Step 2: Remove subsets (e.g. 09:00-10:00 when 06:00-10:00 exists for same trainer/date/location)
        const subsetRows: any[] = await this.dataSource.query(`
          SELECT sub.id as sub_id
          FROM trainer_availability sub
          INNER JOIN trainer_availability parent
          ON sub.trainer_id = parent.trainer_id
            AND sub.date = parent.date
            AND sub.location_id = parent.location_id
            AND sub.\`from\` >= parent.\`from\`
            AND sub.\`to\` <= parent.\`to\`
            AND sub.id != parent.id
            AND (sub.\`from\` > parent.\`from\` OR sub.\`to\` < parent.\`to\`)
        `);
        const subsetIds = subsetRows.map((r: any) => r.sub_id).filter(Boolean);
        if (subsetIds.length > 0) {
          const subPh = subsetIds.map(() => '?').join(', ');
          const subResult: any = await this.dataSource.query(
            `DELETE FROM trainer_availability WHERE id IN (${subPh})`,
            subsetIds,
          );
          if (subResult?.affectedRows > 0) {
            this.logger.log(`Removed ${subResult.affectedRows} subset availability records`);
          }
        }
      } catch (err: any) {
        this.logger.warn(`Availability dedup: ${err.message}`);
      }

      // Trim trailing spaces from training type names
      try {
        await this.dataSource.query(`UPDATE training_type SET name_de = TRIM(name_de) WHERE name_de LIKE '% '`);
        await this.dataSource.query(`UPDATE training_type SET name_en = TRIM(name_en) WHERE name_en LIKE '% '`);
      } catch (err: any) {
        this.logger.warn(`Training type trim: ${err.message}`);
      }

      this.logger.log('Location setup complete');
    } catch (err: any) {
      this.logger.warn(`Location setup error: ${err.message}`);
    }
  }

  /**
   * Ensures credit packages from sihltraining.ch/preise/ exist.
   * Einzellektion (1 credit), Basic (10), Advanced (30).
   */
  private async ensureCreditPackages() {
    try {
      // Create table if not exists
      await this.dataSource.query(`
        CREATE TABLE IF NOT EXISTS credit_package (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(100) NOT NULL,
          credits INT NOT NULL DEFAULT 0,
          price DECIMAL(10,2) NOT NULL DEFAULT 0,
          price_per_session DECIMAL(10,2) DEFAULT NULL,
          duration_months INT DEFAULT NULL,
          description TEXT DEFAULT NULL,
          \`includes\` TEXT DEFAULT NULL,
          sort_order INT DEFAULT 0,
          active TINYINT(1) DEFAULT 1
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
      `);

      const packages = [
        {
          name: 'Einzellektion',
          credits: 1,
          price: 175.00,
          pricePerSession: 175.00,
          durationMonths: 1,
          description: '1 × 60 Min. Personal Training',
          includes: 'Training Service',
          sortOrder: 1,
        },
        {
          name: 'Basic',
          credits: 10,
          price: 1350.00,
          pricePerSession: 135.00,
          durationMonths: 3,
          description: '10 × 60 Min. Personal Training',
          includes: '1× Leistungsanalyse, Training Service',
          sortOrder: 2,
        },
        {
          name: 'Advanced',
          credits: 30,
          price: 3750.00,
          pricePerSession: 125.00,
          durationMonths: 6,
          description: '30 × 60 Min. Personal Training',
          includes: 'Spiroergometrie, 2× Leistungsanalyse, Training Service',
          sortOrder: 3,
        },
      ];

      for (const pkg of packages) {
        const [existing]: any = await this.dataSource.query(
          'SELECT id FROM credit_package WHERE name = ?',
          [pkg.name],
        );
        if (existing) {
          await this.dataSource.query(
            'UPDATE credit_package SET credits = ?, price = ?, price_per_session = ?, duration_months = ?, description = ?, `includes` = ?, sort_order = ?, active = 1 WHERE id = ?',
            [pkg.credits, pkg.price, pkg.pricePerSession, pkg.durationMonths, pkg.description, pkg.includes, pkg.sortOrder, existing.id],
          );
          this.logger.log(`Package "${pkg.name}" updated`);
        } else {
          await this.dataSource.query(
            'INSERT INTO credit_package (name, credits, price, price_per_session, duration_months, description, `includes`, sort_order, active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)',
            [pkg.name, pkg.credits, pkg.price, pkg.pricePerSession, pkg.durationMonths, pkg.description, pkg.includes, pkg.sortOrder],
          );
          this.logger.log(`Package "${pkg.name}" created`);
        }
      }
      this.logger.log('Credit packages setup complete');
    } catch (err: any) {
      this.logger.warn(`Credit packages setup error: ${err.message}`);
    }
  }

  /**
   * Ensures every active client has at least one trainer assigned.
   * 1) Syncs trainer_client from the old PHP DB (if reachable).
   * 2) Fallback: infers assignments from training history for clients
   *    that still have zero trainers assigned.
   */
  private async syncTrainerClients() {
    // ── Step 1: sync from old PHP DB ──────────────────────────────
    let oldConn: mysql2.Connection | null = null;
    try {
      oldConn = await mysql2.createConnection({
        host: 'sihltrai.mysql.db.internal',
        user: 'sihltrai_admin',
        password: 'sihltrai_admin',
        database: 'sihltrai_admin',
        connectTimeout: 5000,
      });

      const [oldRows]: any = await oldConn.execute(
        'SELECT trainer_id, client_id FROM trainer_client',
      );

      const [existingRows]: any = await this.dataSource.query(
        'SELECT trainer_id, client_id FROM trainer_client',
      );
      const existingSet = new Set(
        existingRows.map((r: any) => `${r.trainer_id}:${r.client_id}`),
      );

      let inserted = 0;
      for (const row of oldRows) {
        const key = `${row.trainer_id}:${row.client_id}`;
        if (existingSet.has(key)) continue;

        try {
          await this.dataSource.query(
            'INSERT INTO trainer_client (trainer_id, client_id) VALUES (?, ?)',
            [row.trainer_id, row.client_id],
          );
          inserted++;
        } catch (err: any) {
          if (err?.errno !== 1062) {
            this.logger.warn(`Failed to sync trainer_client ${row.trainer_id}→${row.client_id}: ${err.message}`);
          }
        }
      }

      if (inserted > 0) {
        this.logger.log(`Synced ${inserted} trainer_client assignments from old DB`);
      } else {
        this.logger.log('All trainer_client assignments already present');
      }
    } catch (err: any) {
      if (
        err.code === 'ENOTFOUND' ||
        err.code === 'ECONNREFUSED' ||
        err.code === 'ETIMEDOUT'
      ) {
        this.logger.log('Old PHP DB not reachable, skipping trainer_client sync');
      } else {
        this.logger.warn(`Trainer_client sync error: ${err.message}`);
      }
    } finally {
      if (oldConn) {
        try { await oldConn.end(); } catch (_) {}
      }
    }

    // ── Step 2: infer from training history ───────────────────────
    // For any active client with zero trainers, assign trainers they
    // have trained with (based on the training table).
    try {
      const orphaned: any[] = await this.dataSource.query(`
        SELECT c.id AS client_id
        FROM client c
        WHERE c.active = 1
          AND c.id NOT IN (SELECT client_id FROM trainer_client)
      `);

      if (orphaned.length === 0) {
        this.logger.log('All active clients have trainer assignments');
        return;
      }

      this.logger.log(`Found ${orphaned.length} active clients without trainer assignment`);

      let inferred = 0;
      for (const row of orphaned) {
        // Find distinct trainers this client has trained with
        const trainerRows: any[] = await this.dataSource.query(
          `SELECT DISTINCT trainer_id FROM training WHERE client_id = ? AND trainer_id IS NOT NULL`,
          [row.client_id],
        );

        // If no training history, assign all active trainers with availability
        const trainers = trainerRows.length > 0
          ? trainerRows
          : await this.dataSource.query(
              `SELECT DISTINCT t.id AS trainer_id FROM trainer t
               WHERE t.active = 1
                 AND EXISTS (SELECT 1 FROM trainer_availability ta WHERE ta.trainer_id = t.id)`,
            );

        for (const t of trainers) {
          try {
            await this.dataSource.query(
              'INSERT IGNORE INTO trainer_client (trainer_id, client_id) VALUES (?, ?)',
              [t.trainer_id, row.client_id],
            );
            inferred++;
          } catch { /* skip duplicates */ }
        }
      }

      if (inferred > 0) {
        this.logger.log(`Inferred ${inferred} trainer_client assignments from training history`);
      }
    } catch (err: any) {
      this.logger.warn(`Trainer_client inference error: ${err.message}`);
    }
  }

  /**
   * Copies file records that are in the old PHP DB but missing in Railway.
   * Only runs when the old DB is reachable (i.e. inside Railway network).
   */
  private async copyMissingFiles() {
    let oldConn: mysql2.Connection | null = null;
    try {
      oldConn = await mysql2.createConnection({
        host: 'sihltrai.mysql.db.internal',
        user: 'sihltrai_admin',
        password: 'sihltrai_admin',
        database: 'sihltrai_admin',
        connectTimeout: 5000,
      });

      // Find IDs that exist in old DB but not in Railway
      const [oldRows]: any = await oldConn.execute(
        'SELECT id, name, date, file, client_id FROM file ORDER BY id',
      );

      const [existingRows]: any = await this.dataSource.query(
        'SELECT id FROM file',
      );
      const existingIds = new Set(existingRows.map((r: any) => r.id));

      let inserted = 0;
      for (const row of oldRows) {
        if (existingIds.has(row.id)) continue;

        // Fix invalid dates (0000-00-00 00:00:00)
        let dateVal = row.date;
        if (
          dateVal &&
          (dateVal.toString().startsWith('0000') ||
            dateVal.toString() === 'Invalid Date')
        ) {
          dateVal = null;
        }

        try {
          await this.dataSource.query(
            'INSERT INTO file (id, name, date, file, client_id) VALUES (?, ?, ?, ?, ?)',
            [row.id, row.name, dateVal, row.file, row.client_id],
          );
          inserted++;
        } catch (err: any) {
          this.logger.warn(`Failed to copy file ${row.id}: ${err.message}`);
        }
      }

      if (inserted > 0) {
        this.logger.log(`Copied ${inserted} missing file records from old DB`);
      } else {
        this.logger.log('All file records already present');
      }
    } catch (err: any) {
      // Old DB not reachable (e.g. running locally) — skip silently
      if (
        err.code === 'ENOTFOUND' ||
        err.code === 'ECONNREFUSED' ||
        err.code === 'ETIMEDOUT'
      ) {
        this.logger.log('Old PHP DB not reachable, skipping file sync');
      } else {
        this.logger.warn(`File sync error: ${err.message}`);
      }
    } finally {
      if (oldConn) {
        try {
          await oldConn.end();
        } catch (_) {}
      }
    }
  }

  /**
   * Rename exercise groups and migrate Shoulder/Spine/Legs from groups to body regions.
   * Idempotent — safe to run multiple times.
   */
  private async migrateExerciseGroups() {
    // 1. Rename groups
    const renames: [string, string][] = [
      ['Balance Board & Sensomotorik', 'Propriozeption'],
      ['Klettern & Slackline', 'Slackline'],
    ];
    for (const [oldName, newName] of renames) {
      try {
        const [existing]: any = await this.dataSource.query(
          'SELECT id FROM exercise_group WHERE name = ?', [oldName],
        );
        if (existing) {
          await this.dataSource.query(
            'UPDATE exercise_group SET name = ? WHERE id = ?', [newName, existing.id],
          );
          this.logger.log(`Renamed group "${oldName}" → "${newName}"`);
        }
      } catch (err: any) {
        this.logger.warn(`Group rename "${oldName}": ${err.message}`);
      }
    }

    // 2. Migrate Shoulder, Spine, Legs from groups → body_region
    const groupsToBodyRegion: [string, string][] = [
      ['Shoulder', 'Shoulder'],
      ['Spine', 'Spine'],
      ['Legs', 'LowerBody'],
    ];
    for (const [groupName, bodyRegion] of groupsToBodyRegion) {
      try {
        const [group]: any = await this.dataSource.query(
          'SELECT id FROM exercise_group WHERE name = ?', [groupName],
        );
        if (group) {
          // Set body_region on exercises that belong to this group (if not already set)
          await this.dataSource.query(
            `UPDATE exercise SET body_region = ? WHERE group_id = ? AND (body_region IS NULL OR body_region = '')`,
            [bodyRegion, group.id],
          );
          // Clear group_id so exercises are no longer tied to the old group
          await this.dataSource.query(
            'UPDATE exercise SET group_id = NULL WHERE group_id = ?', [group.id],
          );
          // Delete the group
          await this.dataSource.query(
            'DELETE FROM exercise_group WHERE id = ?', [group.id],
          );
          this.logger.log(`Migrated group "${groupName}" → bodyRegion "${bodyRegion}", group deleted`);
        }
      } catch (err: any) {
        this.logger.warn(`Group→bodyRegion migration "${groupName}": ${err.message}`);
      }
    }
  }
}

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

    const migrations: string[] = [
      `ALTER TABLE client ADD COLUMN auto_training_notify TINYINT(1) NOT NULL DEFAULT 0`,
      `ALTER TABLE feedback ADD COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP`,
      `ALTER TABLE feedback ADD COLUMN sender_type VARCHAR(10) DEFAULT NULL`,
      // Credit tracking on training
      `ALTER TABLE training ADD COLUMN credit_pack_id INT DEFAULT NULL`,
      // Exercise anatomical metadata (for AI plan selection)
      `ALTER TABLE exercise ADD COLUMN body_region VARCHAR(20) DEFAULT NULL`,
      `ALTER TABLE exercise ADD COLUMN primary_muscle_group VARCHAR(50) DEFAULT NULL`,
      `ALTER TABLE exercise ADD COLUMN target_joint VARCHAR(30) DEFAULT NULL`,
      `ALTER TABLE exercise ADD COLUMN movement_pattern VARCHAR(20) DEFAULT NULL`,
      // Location buffer for 3-tier dynamic buffer system
      `ALTER TABLE location ADD COLUMN buffer_minutes INT DEFAULT 30`,
    ];

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

    // Ensure correct locations with buffer_minutes values
    await this.ensureLocations();

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
      this.logger.log('Location setup complete');
    } catch (err: any) {
      this.logger.warn(`Location setup error: ${err.message}`);
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
}

import { Injectable, OnApplicationBootstrap, Logger } from '@nestjs/common';
import { DataSource } from 'typeorm';

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
    ];

    // Create tables if they don't exist
    const createTables: { name: string; sql: string }[] = [
      {
        name: 'push_subscription',
        sql: `CREATE TABLE IF NOT EXISTS push_subscription (
          id INT AUTO_INCREMENT PRIMARY KEY,
          client_id INT NOT NULL,
          endpoint TEXT NOT NULL,
          p256dh TEXT NOT NULL,
          auth TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_push_client (client_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
      },
      {
        name: 'tbl_file',
        sql: `CREATE TABLE IF NOT EXISTS tbl_file (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(255) DEFAULT NULL,
          date DATE DEFAULT NULL,
          file VARCHAR(255) DEFAULT NULL,
          client_id INT DEFAULT NULL,
          INDEX idx_file_client (client_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
      },
    ];

    for (const tbl of createTables) {
      try {
        await this.dataSource.query(tbl.sql);
        this.logger.log(`${tbl.name} table ready`);
      } catch (err: any) {
        this.logger.warn(`${tbl.name} table creation: ${err.message}`);
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
  }
}

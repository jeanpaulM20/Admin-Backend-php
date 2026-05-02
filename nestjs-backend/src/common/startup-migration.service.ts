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
      `ALTER TABLE tbl_client ADD COLUMN auto_training_notify TINYINT(1) NOT NULL DEFAULT 0`,
    ];

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

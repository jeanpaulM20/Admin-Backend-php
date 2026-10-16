import { In, Repository } from 'typeorm';
import type { PolarConnection } from '../domain/polar-connection';
import type { ImportedExerciseStore, PolarConnectionRepository } from '../application/ports';
import { PolarConnectionRow } from './polar-connection.entity';
import { PolarExerciseImportRow } from './polar-exercise-import.entity';
import { TokenCipher } from './token-cipher';

export class TypeOrmPolarConnectionRepository implements PolarConnectionRepository {
  constructor(
    private readonly rows: Repository<PolarConnectionRow>,
    private readonly cipher: TokenCipher,
  ) {}

  async find(clientId: number): Promise<PolarConnection | null> {
    const row = await this.rows.findOne({ where: { clientId } });
    if (!row) return null;
    let accessToken: string;
    try {
      accessToken = this.cipher.decrypt(row.accessTokenEnc);
    } catch {
      // Schlüssel gewechselt oder Daten beschädigt → wie „nicht verbunden";
      // ein erneutes Verbinden überschreibt die Zeile.
      return null;
    }
    return {
      clientId: row.clientId,
      polarUserId: row.polarUserId,
      accessToken,
      expiresAt: row.expiresAt ?? null,
      connectedAt: row.connectedAt,
      lastSyncAt: row.lastSyncAt ?? null,
    };
  }

  async save(conn: PolarConnection): Promise<void> {
    const existing = await this.rows.findOne({ where: { clientId: conn.clientId } });
    await this.rows.save({
      ...(existing ? { id: existing.id } : {}),
      clientId: conn.clientId,
      polarUserId: conn.polarUserId,
      accessTokenEnc: this.cipher.encrypt(conn.accessToken),
      expiresAt: conn.expiresAt,
      connectedAt: conn.connectedAt,
      lastSyncAt: conn.lastSyncAt,
    });
  }

  async delete(clientId: number): Promise<void> {
    await this.rows.delete({ clientId });
  }

  async markSynced(clientId: number, at: Date): Promise<void> {
    await this.rows.update({ clientId }, { lastSyncAt: at });
  }
}

export class TypeOrmImportedExerciseStore implements ImportedExerciseStore {
  constructor(private readonly rows: Repository<PolarExerciseImportRow>) {}

  async importedIds(clientId: number, exerciseIds: string[]): Promise<Set<string>> {
    if (!exerciseIds.length) return new Set();
    const found = await this.rows.find({
      where: { clientId, exerciseId: In(exerciseIds) },
      select: ['exerciseId'],
    });
    return new Set(found.map((r) => r.exerciseId));
  }

  async record(clientId: number, exerciseId: string, reviewId: number | null): Promise<void> {
    await this.rows.insert({ clientId, exerciseId, reviewId, importedAt: new Date() });
  }
}

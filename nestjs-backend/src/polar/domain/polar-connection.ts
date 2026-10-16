/** Verknüpfung eines Clients mit seinem Polar-Account. */
export interface PolarConnection {
  clientId: number;
  polarUserId: string;
  /** Klartext — verschlüsselt wird erst beim Speichern (Adapter). */
  accessToken: string;
  /** null = Polar hat keinen Ablauf genannt */
  expiresAt: Date | null;
  connectedAt: Date;
  lastSyncAt: Date | null;
}

/** Ein Token, das in den nächsten 5 Minuten abläuft, gilt schon als abgelaufen. */
const EXPIRY_MARGIN_MS = 5 * 60_000;

export function isExpired(conn: Pick<PolarConnection, 'expiresAt'>, now: Date): boolean {
  return conn.expiresAt !== null && conn.expiresAt.getTime() - EXPIRY_MARGIN_MS <= now.getTime();
}

/**
 * member-id für POST /v3/users. Mit Polar-User-ID, damit ein späterer
 * Wechsel auf einen anderen Polar-Account nicht an „schon vergeben" scheitert.
 */
export function memberId(clientId: number, polarUserId: string): string {
  return `sihl-${clientId}-${polarUserId}`;
}

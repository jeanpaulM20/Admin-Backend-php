import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

/**
 * AES-256-GCM für Polar-Tokens in der Datenbank. Format:
 *   v1:<iv>:<tag>:<ciphertext>   (alles base64)
 * Ein DB-Dump allein reicht so nicht, um Trainingsdaten bei Polar abzurufen.
 */
export class TokenCipher {
  constructor(private readonly key: Buffer) {
    if (key.length !== 32) throw new Error('POLAR_TOKEN_KEY muss 32 Bytes (base64) lang sein');
  }

  encrypt(plain: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const ct = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
    return ['v1', iv.toString('base64'), cipher.getAuthTag().toString('base64'), ct.toString('base64')].join(':');
  }

  decrypt(stored: string): string {
    const [version, iv, tag, ct] = stored.split(':');
    if (version !== 'v1' || !iv || !tag || ct === undefined) throw new Error('Unbekanntes Token-Format');
    const decipher = createDecipheriv('aes-256-gcm', this.key, Buffer.from(iv, 'base64'));
    decipher.setAuthTag(Buffer.from(tag, 'base64'));
    return Buffer.concat([decipher.update(Buffer.from(ct, 'base64')), decipher.final()]).toString('utf8');
  }
}

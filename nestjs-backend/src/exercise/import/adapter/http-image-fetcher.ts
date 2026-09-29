import type { ImageFetcher } from '../application/ports';

/** Bildabruf über HTTP — nur Bildtypen, begrenzte Grösse, mit Zeitlimit. */
export class HttpImageFetcher implements ImageFetcher {
  static readonly MAX_BYTES = 2 * 1024 * 1024;
  private static readonly TYPES = ['image/webp', 'image/png', 'image/jpeg'];

  constructor(private readonly fetchImpl: typeof fetch = fetch, private readonly timeoutMs = 15000) {}

  async fetch(url: string): Promise<Uint8Array | null> {
    const response = await this.fetchImpl(url, {
      headers: { Accept: 'image/webp,image/png,image/jpeg', 'User-Agent': 'SihlMove-Katalog/1.0' },
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!response.ok) return null;
    const type = (response.headers.get('content-type') ?? '').split(';')[0].trim();
    // GitHub raw liefert application/octet-stream — dann entscheidet der Inhalt.
    if (type && type !== 'application/octet-stream' && !HttpImageFetcher.TYPES.includes(type)) return null;
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.length === 0 || bytes.length > HttpImageFetcher.MAX_BYTES) return null;
    return isImage(bytes) ? bytes : null;
  }
}

/** PNG, WebP (RIFF….WEBP) oder JPEG anhand der ersten Bytes. */
export function isImage(bytes: Uint8Array): boolean {
  const png = bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47;
  const webp = bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46
    && bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50;
  const jpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  return png || webp || jpeg;
}

/** MIME-Typ für die Auslieferung — der Pfad heisst icon.png, der Inhalt entscheidet. */
export function imageMime(bytes: Uint8Array): 'image/png' | 'image/webp' | 'image/jpeg' {
  if (bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[8] === 0x57 && bytes[9] === 0x45) return 'image/webp';
  if (bytes[0] === 0xff && bytes[1] === 0xd8) return 'image/jpeg';
  return 'image/png';
}

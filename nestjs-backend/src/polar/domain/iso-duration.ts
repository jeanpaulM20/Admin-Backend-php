/**
 * ISO-8601-Dauern, wie Polar sie liefert: "PT2H44M", "PT210.026S", "P1DT2H".
 * Nur Tage/Stunden/Minuten/Sekunden — Jahre/Monate kommen bei Trainings nicht vor.
 */
const PATTERN = /^P(?:(\d+(?:\.\d+)?)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?)?$/;

/** Dauer in Sekunden — oder null, wenn der Text keine gültige Dauer ist. */
export function parseIsoDurationSeconds(value: unknown): number | null {
  if (typeof value !== 'string') return null;
  const m = PATTERN.exec(value.trim());
  if (!m || value.trim() === 'P' || value.trim() === 'PT') return null;
  const [, d, h, min, s] = m.map((x) => (x === undefined ? 0 : Number(x))) as number[];
  const total = d * 86400 + h * 3600 + min * 60 + s;
  return Number.isFinite(total) ? total : null;
}

/** "HH:MM:SS" für die review.duration-Spalte (TIME). */
export function formatHms(totalSeconds: number): string {
  const secs = Math.max(0, Math.round(totalSeconds));
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = secs % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

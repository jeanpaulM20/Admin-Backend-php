/** Namen vergleichbar machen: Kleinschreibung, Umlaute, Sonderzeichen, Füllwörter. */
const STOPWORDS = new Set(['mit', 'im', 'am', 'der', 'die', 'das', 'und', 'auf', 'with', 'the', 'on', 'and']);

export function normalizeName(name: string): string {
  return name
    .toLowerCase()
    .replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss')
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9 ]+/g, ' ')
    .split(/\s+/)
    .filter((t) => t && !STOPWORDS.has(t))
    .join(' ')
    .trim();
}

export function tokens(name: string): Set<string> {
  return new Set(normalizeName(name).split(' ').filter(Boolean));
}

/** Jaccard-Ähnlichkeit zweier Token-Mengen, 0–1. */
export function similarity(a: string, b: string): number {
  const ta = tokens(a), tb = tokens(b);
  if (!ta.size || !tb.size) return 0;
  let common = 0;
  for (const t of ta) if (tb.has(t)) common++;
  return common / (ta.size + tb.size - common);
}

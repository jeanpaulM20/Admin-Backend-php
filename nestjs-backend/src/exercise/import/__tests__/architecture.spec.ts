import * as fs from 'fs';
import * as path from 'path';

/**
 * Architektur-Test: Abhängigkeiten zeigen nur nach innen.
 *   domain      → nichts ausserhalb von domain/ und dem Fachvokabular
 *   application → domain (nie adapter/interface, nie typeorm/nest)
 *   adapter     → domain, application
 *   interface   → alles, und nur hier wird process.env gelesen
 */
const ROOT = path.resolve(__dirname, '..');

function sourceFiles(dir: string): string[] {
  return fs.readdirSync(path.join(ROOT, dir))
    .filter((f) => f.endsWith('.ts') && !f.endsWith('.spec.ts'))
    .map((f) => path.join(ROOT, dir, f));
}

/** Quelltext ohne Kommentare — der Test prüft Code, nicht Prosa. */
function codeOf(file: string): string {
  return fs.readFileSync(file, 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/(^|[^:])\/\/.*$/gm, '$1');
}

function importsOf(file: string): string[] {
  return [...codeOf(file).matchAll(/from\s+'([^']+)'/g)].map((m) => m[1]);
}

const forbid = (layer: string, banned: RegExp, why: string) => {
  it(`${layer} importiert nicht ${why}`, () => {
    for (const file of sourceFiles(layer)) {
      for (const imp of importsOf(file)) {
        expect({ file: path.basename(file), import: imp, ok: !banned.test(imp) })
          .toEqual({ file: path.basename(file), import: imp, ok: true });
      }
    }
  });
};

describe('Katalog-Import — Schichtung', () => {
  forbid('domain', /typeorm|@nestjs|\.\.\/application|\.\.\/adapter|\.\.\/interface|entities\//, 'Framework, Datenbank oder äussere Schichten');
  forbid('application', /typeorm|@nestjs|\.\.\/adapter|\.\.\/interface|entities\//, 'Adapter, Interface oder Framework');
  forbid('adapter', /\.\.\/interface/, 'die Interface-Schicht');

  it('nur die Interface-Schicht liest process.env', () => {
    for (const layer of ['domain', 'application', 'adapter']) {
      for (const file of sourceFiles(layer)) {
        expect({ file: path.basename(file), readsEnv: /process\.env/.test(codeOf(file)) })
          .toEqual({ file: path.basename(file), readsEnv: false });
      }
    }
  });
});

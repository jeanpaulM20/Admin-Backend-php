import * as fs from 'fs';
import * as path from 'path';

/** training-plan/domain: reine Fachlogik — kein Framework, keine Datenbank, keine Konfiguration. */
const DOMAIN = path.resolve(__dirname, '..', 'domain');

const codeOf = (file: string) =>
  fs.readFileSync(file, 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/(^|[^:])\/\/.*$/gm, '$1');

describe('Plan-Generator — Domain-Schicht', () => {
  const files = fs.readdirSync(DOMAIN).filter((f) => f.endsWith('.ts')).map((f) => path.join(DOMAIN, f));

  it('enthält Dateien', () => expect(files.length).toBeGreaterThan(0));

  it('importiert weder typeorm, Nest, Entities noch den Service', () => {
    for (const file of files) {
      for (const [, imp] of codeOf(file).matchAll(/from\s+'([^']+)'/g)) {
        expect({ file: path.basename(file), import: imp, ok: !/typeorm|@nestjs|entities\/|ai-plan\.service|\.\.\/adapter|\.\.\/interface/.test(imp) })
          .toEqual({ file: path.basename(file), import: imp, ok: true });
      }
    }
  });

  it('liest kein process.env', () => {
    for (const file of files) {
      expect({ file: path.basename(file), readsEnv: /process\.env/.test(codeOf(file)) })
        .toEqual({ file: path.basename(file), readsEnv: false });
    }
  });
});

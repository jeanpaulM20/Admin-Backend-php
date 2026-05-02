import { DefaultNamingStrategy, NamingStrategyInterface } from 'typeorm';

/**
 * The legacy PHP (Yii) application used `tablePrefix => 'tbl_'` so every
 * MySQL table is prefixed with `tbl_`.  Rather than hard-coding the prefix
 * in every @Entity({ name: 'tbl_xxx' }), we apply it once here.
 *
 * The SQLite dev database (synchronize: true) will also get the prefix,
 * which is fine — it keeps parity with production.
 */
export class TblNamingStrategy
  extends DefaultNamingStrategy
  implements NamingStrategyInterface
{
  tableName(className: string, customName: string): string {
    const base = customName || super.tableName(className, customName);
    return base.startsWith('tbl_') ? base : `tbl_${base}`;
  }
}

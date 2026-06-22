// TransLOG-X — Migration Runner (idempotent)
// Usage: node supabase/run_migrations.mjs
// Usage: node supabase/run_migrations.mjs --reset   (drop all & re-run)
import pg from 'pg';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const { Client } = pg;
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RESET = process.argv.includes('--reset');

const DB_URL = process.env.DATABASE_URL ||
  'postgresql://postgres.eccermneumcskamtitqh:Maleeka12062015@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres';

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

const client = new Client({ connectionString: DB_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  await client.connect();
  console.log('✅ Connected to Supabase\n');

  // Create migration tracking table
  await client.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id          SERIAL PRIMARY KEY,
      filename    TEXT NOT NULL UNIQUE,
      ran_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      checksum    TEXT
    );
  `);

  if (RESET) {
    console.log('⚠️  RESET mode — dropping and re-running all migrations\n');
    await client.query(`DELETE FROM _migrations`);
  }

  // Get already-run migrations
  const { rows } = await client.query('SELECT filename FROM _migrations ORDER BY id');
  const done = new Set(rows.map(r => r.filename));

  const files = fs.readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort();

  for (const file of files) {
    if (done.has(file)) {
      console.log(`⏭️  Skip:    ${file}  (already run)`);
      continue;
    }

    const filePath = path.join(MIGRATIONS_DIR, file);
    const sql = fs.readFileSync(filePath, 'utf8');
    console.log(`⏳ Running: ${file}`);

    const noTx = sql.trimStart().startsWith('-- noTransaction');

    try {
      if (!noTx) await client.query('BEGIN');
      await client.query(sql);
      await client.query(
        `INSERT INTO _migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING`,
        [file]
      );
      if (!noTx) await client.query('COMMIT');
      console.log(`✅ Done:    ${file}\n`);
    } catch (err) {
      if (!noTx) await client.query('ROLLBACK');
      console.error(`❌ Failed:  ${file}`);
      console.error(`   ${err.message}\n`);
      await client.end();
      process.exit(1);
    }
  }

  await client.end();
  console.log('🎉 Migration complete.');
}

run().catch(async err => {
  console.error('Fatal:', err.message);
  try { await client.end(); } catch {}
  process.exit(1);
});

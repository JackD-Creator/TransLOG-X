import pg from 'pg';
const { Client } = pg;
const DB_URL = process.env.DATABASE_URL;
const client = new Client({ connectionString: DB_URL, ssl: { rejectUnauthorized: false } });
await client.connect();
const done = [
  '00_foundation.sql','01_kfa_catalog.sql','02_m1_inventory.sql',
  '03_m2_procurement.sql','04_m3_order.sql','05_m4_warehouse.sql'
];
for (const f of done) {
  await client.query('INSERT INTO _migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING', [f]);
  console.log('✅ Registered:', f);
}
await client.end();
console.log('Done.');

import pkg from 'pg'
const { Client } = pkg

const c = new Client({
  connectionString: 'postgresql://postgres.eccermneumcskamtitqh:Maleeka12062015@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres',
  ssl: { rejectUnauthorized: false }
})

await c.connect()

await c.query(`
  ALTER TABLE kfa_drugs
    ALTER COLUMN generik         DROP NOT NULL,
    ALTER COLUMN is_fornas       DROP NOT NULL,
    ALTER COLUMN is_narkotika    DROP NOT NULL,
    ALTER COLUMN is_psikotropika DROP NOT NULL,
    ALTER COLUMN is_prekursor    DROP NOT NULL,
    ALTER COLUMN is_obat_keras   DROP NOT NULL
`)
console.log('kfa_drugs nullable done')

await c.end()

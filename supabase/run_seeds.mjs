import { readFileSync } from 'fs'
import pkg from 'pg'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const { Client } = pkg
const __dirname = dirname(fileURLToPath(import.meta.url))

const client = new Client({
  connectionString: 'postgresql://postgres.eccermneumcskamtitqh:Maleeka12062015@aws-1-ap-northeast-2.pooler.supabase.com:6543/postgres',
  ssl: { rejectUnauthorized: false }
})

await client.connect()
console.log('Connected to Supabase.')

const seeds = [
  '../seeds data/kfa/seed_kfa_drugs.sql',
  '../seeds data/kfa/seed_kfa_alkes.sql',
  '../seeds data/kfa/seed_fornas_drugs.sql',
]

for (const file of seeds) {
  const path = resolve(__dirname, file)
  const name = file.split('/').pop()
  process.stdout.write(`Loading ${name}... `)
  try {
    const content = readFileSync(path, 'utf8')
    await client.query(content)
    console.log('done')
  } catch (e) {
    console.log(`\nERROR: ${e.message}`)
  }
}

await client.end()
console.log('Selesai.')

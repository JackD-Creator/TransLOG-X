// Generate TypeScript types from Supabase schema
// Usage: node supabase/gen_types.mjs
import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PROJECT_REF = 'eccermneumcskamtitqh';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjEzMTQ3NSwiZXhwIjoyMDk3NzA3NDc1fQ.ohQ1dVpjmYPSqoASUvRjtsLSuaAts3rhzkOQR4FdBQU';

const OUT = path.join(__dirname, '..', 'app', 'types', 'database.types.ts');

const url = `https://api.supabase.com/v1/projects/${PROJECT_REF}/types/typescript`;

const options = {
  headers: {
    Authorization: `Bearer ${SERVICE_KEY}`,
    'Content-Type': 'application/json'
  }
};

console.log('Fetching TypeScript types from Supabase...');

https.get(url, options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    if (res.statusCode !== 200) {
      console.error('Error:', res.statusCode, data.slice(0, 200));
      process.exit(1);
    }
    const parsed = JSON.parse(data);
    const types = parsed.types || data;
    fs.mkdirSync(path.dirname(OUT), { recursive: true });
    fs.writeFileSync(OUT, typeof types === 'string' ? types : JSON.stringify(types, null, 2));
    console.log('✅ Types written to', OUT);
  });
}).on('error', err => {
  console.error('Request failed:', err.message);
  process.exit(1);
});

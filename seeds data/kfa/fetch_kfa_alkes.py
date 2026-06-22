"""
Fetch KFA alkes from SATUSEHAT Sandbox → seeds data/seed_kfa_alkes.sql
"""
import requests, json, time, sys

CLIENT_ID     = 'dSq3O6OrBEnupsbhtX0bGPQAC7sATroRDUqlGo56D7o6eGbG'
CLIENT_SECRET = 'li5BdCna0GsFFIVwpRDPsAzbUxWglXzzCCx0AmgTCw2A22SKnGN3GwzzuhVAkrzm'
BASE_URL      = 'https://api-satusehat-stg.kemkes.go.id'
TOKEN_URL     = f'{BASE_URL}/oauth2/v1/accesstoken?grant_type=client_credentials'
KFA_URL       = f'{BASE_URL}/kfa-v2/products/all'
OUT_JSON      = '/tmp/kfa_alkes.json'
OUT_SQL       = 'd:/TransCPG-X/seeds data/seed_kfa_alkes.sql'
PAGE_SIZE     = 100

def esc(v):
    if v is None:
        return 'NULL'
    s = str(v).strip()
    if not s:
        return 'NULL'
    return "'" + s.replace("'", "''") + "'"

def get_token():
    r = requests.post(TOKEN_URL, data={'client_id': CLIENT_ID, 'client_secret': CLIENT_SECRET}, timeout=30)
    r.raise_for_status()
    return r.json()['access_token']

def chunked(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

print("Getting token...")
token = get_token()
headers = {'Authorization': f'Bearer {token}'}

r0 = requests.get(KFA_URL, headers=headers,
                  params={'page': 1, 'size': 1, 'product_type': 'alkes'}, timeout=30)
total = r0.json()['total']
pages = (total + PAGE_SIZE - 1) // PAGE_SIZE
print(f"Total: {total} alkes, {pages} pages")

products = []
for pg in range(1, pages + 1):
    r = requests.get(KFA_URL, headers=headers,
                     params={'page': pg, 'size': PAGE_SIZE, 'product_type': 'alkes'}, timeout=30)
    if r.status_code == 401:
        print("  Token expired, refreshing...")
        token = get_token()
        headers = {'Authorization': f'Bearer {token}'}
        r = requests.get(KFA_URL, headers=headers,
                         params={'page': pg, 'size': PAGE_SIZE, 'product_type': 'alkes'}, timeout=30)
    if r.status_code != 200:
        print(f"  ERROR page {pg}: {r.status_code} {r.text[:200]}")
        continue
    items = r.json().get('items', {}).get('data', [])
    products.extend(items)
    if pg % 100 == 0 or pg == pages:
        print(f"  Page {pg}/{pages} — {len(products):,} products so far")
    time.sleep(0.05)

print(f"\nFetched {len(products):,} alkes total")
with open(OUT_JSON, 'w', encoding='utf-8') as f:
    json.dump(products, f, ensure_ascii=False)
print(f"Saved JSON -> {OUT_JSON}")

# ── Generate SQL ──────────────────────────────────────────────────────────
print("Generating SQL...")

create_sql = """\
-- KFA Alat Kesehatan (SATUSEHAT Sandbox) — 69,492 produk alkes
CREATE TABLE IF NOT EXISTS kfa_alkes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kfa_code            VARCHAR(20) NOT NULL UNIQUE,
  name                TEXT NOT NULL,
  nama_dagang         TEXT,
  farmalkes_type      VARCHAR(100),
  farmalkes_group     VARCHAR(50),
  med_dev_jenis       TEXT,
  med_dev_kategori    TEXT,
  med_dev_subkategori TEXT,
  med_dev_kelas_risiko VARCHAR(10),
  manufacturer        TEXT,
  nie                 VARCHAR(100),
  fix_price           INTEGER,
  uom                 VARCHAR(50),
  active              BOOLEAN DEFAULT TRUE,
  state               VARCHAR(20),
  template_kfa_code   VARCHAR(20),
  template_name       TEXT,
  updated_at          TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS kfa_alkes_code_idx ON kfa_alkes (kfa_code);
CREATE INDEX IF NOT EXISTS kfa_alkes_name_trgm ON kfa_alkes USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS kfa_alkes_kategori_idx ON kfa_alkes (med_dev_kategori);
CREATE INDEX IF NOT EXISTS kfa_alkes_kelas_idx ON kfa_alkes (med_dev_kelas_risiko);
"""

def extract_row(p):
    tmpl = p.get('product_template') or {}
    return (
        p.get('kfa_code'),
        p.get('name'),
        p.get('nama_dagang'),
        (p.get('farmalkes_type') or {}).get('name'),
        (p.get('farmalkes_type') or {}).get('group'),
        p.get('med_dev_jenis'),
        p.get('med_dev_kategori'),
        p.get('med_dev_subkategori'),
        p.get('med_dev_kelas_risiko'),
        p.get('manufacturer'),
        p.get('nie'),
        p.get('fix_price') if isinstance(p.get('fix_price'), int) else None,
        (p.get('uom') or {}).get('name'),
        p.get('active', True),
        p.get('state'),
        tmpl.get('kfa_code'),
        tmpl.get('name'),
        p.get('updated_at'),
    )

rows = [extract_row(p) for p in products if p.get('kfa_code')]

parts = [create_sql]
for chunk in chunked(rows, 500):
    vals = ',\n'.join(
        f"  ({esc(r[0])}, {esc(r[1])}, {esc(r[2])}, {esc(r[3])}, {esc(r[4])}, "
        f"{esc(r[5])}, {esc(r[6])}, {esc(r[7])}, {esc(r[8])}, {esc(r[9])}, "
        f"{esc(r[10])}, {'NULL' if r[11] is None else r[11]}, {esc(r[12])}, "
        f"{str(r[13]).upper()}, {esc(r[14])}, {esc(r[15])}, {esc(r[16])}, {esc(r[17])})"
        for r in chunk
    )
    parts.append(
        "INSERT INTO kfa_alkes (kfa_code, name, nama_dagang, farmalkes_type, farmalkes_group, "
        "med_dev_jenis, med_dev_kategori, med_dev_subkategori, med_dev_kelas_risiko, "
        "manufacturer, nie, fix_price, uom, active, state, template_kfa_code, template_name, updated_at)\n"
        "VALUES\n" + vals
        + "\nON CONFLICT (kfa_code) DO UPDATE SET name = EXCLUDED.name, state = EXCLUDED.state;\n"
    )

sql = '\n'.join(parts)
with open(OUT_SQL, 'w', encoding='utf-8') as f:
    f.write(sql)
print(f"Written {len(rows):,} rows, {len(sql)//1024} KB -> {OUT_SQL}")

/**
 * TransLOG-X — Warehouse / Stock Movement Seed
 * Prasyarat: seed_inventory.mjs sudah dijalankan
 * Membuat: ~60 stock movements selama 30 hari terakhir
 *
 * Jalankan: node supabase/seed_warehouse.mjs
 */
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://eccermneumcskamtitqh.supabase.co'
const SERVICE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjEzMTQ3NSwiZXhwIjoyMDk3NzA3NDc1fQ.ohQ1dVpjmYPSqoASUvRjtsLSuaAts3rhzkOQR4FdBQU'

const sb = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
})

function daysAgo(n, hour = 9) {
  const d = new Date()
  d.setDate(d.getDate() - n)
  d.setHours(hour, Math.floor(Math.random() * 60), 0, 0)
  return d.toISOString()
}

async function run() {
  console.log('🌱 Seed warehouse movements dimulai...\n')

  const { data: tenant } = await sb.from('tenants').select('id').eq('email', 'admin@rsudemo.id').single()
  if (!tenant) { console.error('❌ Tenant tidak ditemukan'); process.exit(1) }
  const tenantId = tenant.id

  const { data: wh } = await sb.from('warehouses').select('id').eq('tenant_id', tenantId).eq('code', 'GD-UTAMA').single()
  const warehouseId = wh.id

  const { data: profile } = await sb.from('profiles').select('id').eq('tenant_id', tenantId).single()
  const userId = profile.id

  // Get products & lots
  const { data: products } = await sb.from('products').select('id, internal_code, name, last_purchase_price').eq('tenant_id', tenantId)
  const { data: lots }     = await sb.from('stock_lots').select('id, product_id, qty_on_hand').eq('tenant_id', tenantId)

  const prodMap = {}
  for (const p of products) prodMap[p.internal_code] = p

  const lotMap = {}
  for (const l of lots) {
    if (!lotMap[l.product_id]) lotMap[l.product_id] = []
    lotMap[l.product_id].push(l)
  }

  // ── Generate movements ───────────────────────────────────────
  // Each movement: [daysAgo, hour, code, type, qty, refType, refNumber, notes]
  const MOVEMENTS = [
    // GRN (receive) — barang masuk dari PO
    [28, 9,  'OBT-001', 'receive',    500,  'po',         'PO-2026-0038', 'GRN dari Kimia Farma — PO Mei'],
    [28, 10, 'OBT-002', 'receive',    300,  'po',         'PO-2026-0038', 'GRN dari Kimia Farma — PO Mei'],
    [25, 8,  'ALK-001', 'receive',   2000,  'po',         'PO-2026-0039', 'GRN Spuit dari Enseval'],
    [25, 9,  'ALK-002', 'receive',    400,  'po',         'PO-2026-0039', 'GRN Infus Set dari Enseval'],
    [20, 14, 'OBT-015', 'receive',     24,  'po',         'PO-2026-0040', 'Emergency GRN Insulin Glargine'],
    [18, 9,  'REG-001', 'receive',    200,  'po',         'PO-2026-0041', 'GRN Reagensia Lab'],
    [18, 9,  'REG-002', 'receive',    100,  'po',         'PO-2026-0041', 'GRN Reagensia Lab'],
    [15, 10, 'OBT-004', 'receive',    400,  'po',         'PO-2026-0042', 'GRN Metformin dari Bernofarm'],
    [15, 10, 'OBT-010', 'receive',    300,  'po',         'PO-2026-0042', 'GRN Captopril dari Bernofarm'],
    [10, 9,  'BMH-001', 'receive',    100,  'po',         'PO-2026-0043', 'GRN Alkohol 70% dari Medifarma'],
    [10, 9,  'BMH-002', 'receive',    500,  'po',         'PO-2026-0043', 'GRN Kasa Steril'],
    [5,  8,  'OBT-001', 'receive',    300,  'po',         'PO-2026-0046', 'GRN Paracetamol parsial'],
    [5,  9,  'ALK-004', 'receive',   1000,  'po',         'PO-2026-0045', 'GRN Masker Bedah'],

    // ISSUE (keluar) — distribusi ke unit
    [27, 11, 'OBT-001', 'issue',     -200,  'picking',    'DO-INT-0070', 'Farmasi Rawat Inap — distribusi harian'],
    [26, 10, 'OBT-002', 'issue',      -80,  'picking',    'DO-INT-0071', 'IGD — emergency stock'],
    [25, 14, 'ALK-001', 'issue',     -500,  'picking',    'DO-INT-0072', 'OK (Kamar Operasi) — distribusi mingguan'],
    [24, 9,  'OBT-004', 'issue',     -120,  'picking',    'DO-INT-0073', 'Poli Penyakit Dalam'],
    [23, 10, 'OBT-010', 'issue',      -90,  'picking',    'DO-INT-0074', 'Poli Jantung'],
    [22, 11, 'OBT-005', 'issue',      -60,  'picking',    'DO-INT-0075', 'Poli Umum'],
    [21, 9,  'ALK-002', 'issue',      -80,  'picking',    'DO-INT-0076', 'Rawat Inap Lantai 2'],
    [20, 14, 'OBT-001', 'issue',     -150,  'picking',    'DO-INT-0077', 'Farmasi — distribusi sore'],
    [19, 10, 'OBT-007', 'issue',     -100,  'picking',    'DO-INT-0078', 'Poli Umum — antibiotik'],
    [18, 11, 'BMH-002', 'issue',     -200,  'picking',    'DO-INT-0079', 'OK & ICU — kebutuhan operasi'],
    [17, 9,  'OBT-002', 'issue',      -60,  'picking',    'DO-INT-0080', 'Poli Anak'],
    [16, 10, 'ALK-001', 'issue',     -300,  'picking',    'DO-INT-0081', 'IGD & Poliklinik'],
    [15, 14, 'OBT-004', 'issue',      -80,  'picking',    'DO-INT-0082', 'Poli Diabetes'],
    [14, 9,  'OBT-011', 'issue',      -70,  'picking',    'DO-INT-0083', 'Poli Jantung — statin'],
    [13, 10, 'ALK-004', 'issue',     -500,  'picking',    'DO-INT-0084', 'Semua unit — distribusi mingguan APD'],
    [12, 11, 'OBT-001', 'issue',     -180,  'picking',    'DO-INT-0085', 'Farmasi Rawat Jalan'],
    [11, 9,  'OBT-008', 'issue',     -150,  'picking',    'DO-INT-0086', 'Poli GI — ranitidine'],
    [10, 14, 'ALK-005', 'issue',     -200,  'picking',    'DO-INT-0087', 'OK — distribusi sarung tangan'],
    [9,  10, 'OBT-002', 'issue',      -40,  'picking',    'DO-INT-0088', 'ICU — antibiotik'],
    [8,  11, 'OBT-004', 'issue',      -60,  'picking',    'DO-INT-0089', 'Poli Interna'],
    [7,  9,  'OBT-001', 'issue',     -200,  'picking',    'DO-INT-0090', 'Farmasi Rawat Inap'],
    [6,  10, 'ALK-002', 'issue',      -60,  'picking',    'DO-INT-0091', 'ICU — infus set'],
    [5,  14, 'OBT-007', 'issue',      -80,  'picking',    'DO-INT-0092', 'IGD — infeksi akut'],
    [4,  10, 'ALK-001', 'issue',     -400,  'picking',    'DO-INT-0093', 'OK — weekly supply'],
    [3,  11, 'OBT-001', 'issue',     -160,  'picking',    'DO-INT-0094', 'Farmasi distribusi harian'],
    [2,  9,  'OBT-010', 'issue',      -50,  'picking',    'DO-INT-0095', 'Poli Jantung'],
    [1,  10, 'OBT-004', 'issue',      -40,  'picking',    'DO-INT-0096', 'Poli DM'],
    [0,  8,  'OBT-002', 'issue',      -30,  'picking',    'DO-INT-0097', 'IGD pagi'],

    // ADJUSTMENT — stock opname correction
    [22, 16, 'OBT-006', 'adjustment',  -5,  'adjustment', 'ADJ-0010',    'Opname — selisih fisik vs sistem'],
    [15, 15, 'ALK-003', 'adjustment',  -2,  'adjustment', 'ADJ-0011',    'Opname — rusak kemasan'],
    [8,  16, 'OBT-012', 'adjustment',  10,  'adjustment', 'ADJ-0012',    'Opname — temukan stok tersembunyi'],
    [3,  15, 'BMH-003', 'adjustment',  -3,  'adjustment', 'ADJ-0013',    'Opname — hilang/rusak'],

    // RETURN_IN — return dari unit
    [20, 15, 'OBT-001', 'return_in',   20,  'picking',    'RET-001',     'Return dari ICU — kelebihan order'],
    [12, 14, 'ALK-002', 'return_in',   10,  'picking',    'RET-002',     'Return dari OK — tidak terpakai'],
  ]

  let ok = 0
  for (const [dayAgo, hour, code, type, qty, refType, refNum, notes] of MOVEMENTS) {
    const prod = prodMap[code]
    if (!prod) continue
    const lot = lotMap[prod.id]?.[0]
    const qtyBefore = Math.abs(qty) * 2
    const qtyAfter  = qtyBefore + qty

    const { error } = await sb.from('stock_movements').insert({
      tenant_id: tenantId, product_id: prod.id,
      warehouse_id: warehouseId, lot_id: lot?.id ?? null,
      movement_type: type, qty,
      qty_before: Math.max(0, qtyBefore),
      qty_after:  Math.max(0, qtyAfter),
      ref_type: refType, ref_number: refNum,
      unit_cost: prod.last_purchase_price,
      notes, performed_by: userId,
      created_at: daysAgo(dayAgo, hour)
    })
    if (error) { process.stdout.write(`❌ ${code} ${type}: ${error.message}\n`) }
    else { ok++; process.stdout.write(`\r   Movements: ${ok}/${MOVEMENTS.length}`) }
  }

  console.log(`\n\n✅ ${ok} stock movements berhasil dibuat`)
  console.log('\n🎉 Seed warehouse selesai!')
  console.log('   Buka /dashboard/warehouse untuk melihat aktivitas')
}

run().catch(err => { console.error('❌ Fatal:', err.message); process.exit(1) })

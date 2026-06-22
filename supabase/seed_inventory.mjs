/**
 * TransLOG-X — Inventory Demo Seed
 * Prasyarat: node supabase/seed_demo.mjs sudah dijalankan (tenant & user ada)
 * Membuat: warehouse, 25 produk, stock_summary, reorder_rules
 *
 * Jalankan: node supabase/seed_inventory.mjs
 */

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://eccermneumcskamtitqh.supabase.co'
const SERVICE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjEzMTQ3NSwiZXhwIjoyMDk3NzA3NDc1fQ.ohQ1dVpjmYPSqoASUvRjtsLSuaAts3rhzkOQR4FdBQU'

const sb = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
})

function addDays(n) {
  const d = new Date()
  d.setDate(d.getDate() + n)
  return d.toISOString().slice(0, 10)
}

// ── 25 produk demo ────────────────────────────────────────────────
// [internal_code, name, category, uom_base, min_stock, max_stock, reorder_point, reorder_qty, price, is_fornas, is_nark, is_psiko, qty_on_hand, expiry_days]
const PRODUCTS = [
  ['OBT-001', 'Paracetamol 500mg Tab',         'obat',      'tablet', 200, 2000, 300, 500,   850,  true,  false, false, 1250, 365],
  ['OBT-002', 'Amoxicillin 500mg Kapsul',       'obat',      'kapsul', 100, 1000, 150, 300,  2100,  true,  false, false,   80, 730],
  ['OBT-003', 'Omeprazole 20mg Kapsul',         'obat',      'kapsul',  50,  500,  80, 200,  3200,  true,  false, false,    0, 365],
  ['OBT-004', 'Metformin 500mg Tab',            'obat',      'tablet', 100,  800, 150, 200,  1500,  true,  false, false,  480, 365],
  ['OBT-005', 'Amlodipine 5mg Tab',             'obat',      'tablet',  50,  500,  75, 150,  2800,  true,  false, false,  120, 730],
  ['OBT-006', 'Cetirizine 10mg Tab',            'obat',      'tablet',  50,  400,  75, 150,  1200, false,  false, false,  210, 365],
  ['OBT-007', 'Ciprofloxacin 500mg Tab',        'obat',      'tablet',  60,  600, 100, 200,  4500,  true,  false, false,  350, 730],
  ['OBT-008', 'Ranitidine 150mg Tab',           'obat',      'tablet',  80,  800, 120, 200,  1800,  true,  false, false,  560, 365],
  ['OBT-009', 'Dexamethasone 0.5mg Tab',        'obat',      'tablet',  50,  500,  80, 150,   950,  true,  false, false,   88, 730],
  ['OBT-010', 'Captopril 25mg Tab',             'obat',      'tablet',  60,  600,  90, 200,  2200,  true,  false, false,  340, 365],
  ['OBT-011', 'Simvastatin 20mg Tab',           'obat',      'tablet',  50,  500,  80, 150,  3100,  true,  false, false,  170, 730],
  ['OBT-012', 'Ibuprofen 400mg Tab',            'obat',      'tablet',  80,  800, 120, 200,  1600, false,  false, false,  620, 365],
  ['OBT-013', 'Domperidone 10mg Tab',           'obat',      'tablet',  50,  500,  75, 150,  2400, false,  false, false,   95, 365],
  ['OBT-014', 'Diazepam 5mg Tab',               'obat',      'tablet',  20,  200,  30,  50,  3500,  true,  false,  true,   35, 730],
  ['OBT-015', 'Insulin Glargine 100U/mL',       'obat',      'vial',    20,  200,  30,  50, 145000, true,  false, false,   12, 180],
  ['ALK-001', 'Spuit 3cc Disposable',           'alkes',     'pcs',    500, 5000, 800,2000,  1500, false,  false, false, 4500, 730],
  ['ALK-002', 'Infus Set Dewasa',               'alkes',     'set',    100, 1000, 150, 400,  8500, false,  false, false,  320, 730],
  ['ALK-003', 'Kateter Urin No.16',             'alkes',     'pcs',     30,  300,  50, 100, 28000, false,  false, false,   45, 730],
  ['ALK-004', 'Masker Bedah 3Ply',              'alkes',     'pcs',    200, 2000, 400,1000,   850, false,  false, false, 1200, 365],
  ['ALK-005', 'Gloves Latex M Non-Steril',      'alkes',     'pasang', 100, 1000, 200, 500,  3500, false,  false, false,  680, 365],
  ['BMH-001', 'Alkohol 70% 1L',                'bmhp',      'botol',   20,  200,  40, 100, 32000, false,  false, false,   60, 365],
  ['BMH-002', 'Kasa Steril 10x10cm',           'bmhp',      'pcs',    100, 1000, 200, 500,  1200, false,  false, false,  450, 365],
  ['BMH-003', 'Plester Elastis 5cm x 4.5m',   'bmhp',      'roll',    30,  300,  50, 100, 18000, false,  false, false,   25, 365],
  ['REG-001', 'Strip Gula Darah Accu-Chek',    'reagensia', 'strip',   50,  500,  80, 200,  6000, false,  false, false,  150,  90],
  ['REG-002', 'Reagen HbA1c Test',             'reagensia', 'test',    20,  200,  40, 100, 85000, false,  false, false,    8,  90],
]

async function run() {
  console.log('🌱 Seed inventory dimulai...\n')

  // ── Get tenant ───────────────────────────────────────────────
  const { data: tenant, error: tErr } = await sb.from('tenants').select('id').eq('email', 'admin@rsudemo.id').single()
  if (tErr || !tenant) {
    console.error('❌ Tenant tidak ditemukan. Jalankan seed_demo.mjs dulu.')
    console.error(tErr?.message)
    process.exit(1)
  }
  const tenantId = tenant.id
  console.log(`✅ Tenant: ${tenantId}`)

  // ── Warehouse ────────────────────────────────────────────────
  let { data: wh } = await sb.from('warehouses').select('id').eq('tenant_id', tenantId).eq('code', 'GD-UTAMA').single()
  if (!wh) {
    const { data: newWh, error: wErr } = await sb.from('warehouses').insert({
      tenant_id: tenantId, code: 'GD-UTAMA', name: 'Gudang Utama RS Demo',
      type: 'main', city: 'Jakarta Selatan', province: 'DKI Jakarta', is_active: true
    }).select('id').single()
    if (wErr) { console.error('❌ Warehouse:', wErr.message); process.exit(1) }
    wh = newWh
    console.log(`✅ Warehouse created: ${wh.id}`)
  } else {
    console.log(`ℹ️  Warehouse exists: ${wh.id}`)
  }
  const warehouseId = wh.id

  // ── Products + Stock ─────────────────────────────────────────
  let ok = 0, skip = 0
  for (const p of PRODUCTS) {
    const [code, name, cat, uom, minStk, maxStk, rop, roq, price, isFornas, isNark, isPsiko, qty, expiryDays] = p

    // Upsert product
    const { data: prod, error: pErr } = await sb.from('products').upsert({
      tenant_id: tenantId, internal_code: code, name, category: cat,
      uom_base: uom, min_stock: minStk, max_stock: maxStk,
      reorder_point: rop, reorder_qty: roq,
      standard_price: price, last_purchase_price: Math.round(price * 0.88),
      is_fornas: isFornas, is_narkotika: isNark, is_psikotropika: isPsiko,
      is_active: true
    }, { onConflict: 'tenant_id,internal_code' }).select('id').single()

    if (pErr) { console.error(`❌ Product ${code}:`, pErr.message); continue }
    const productId = prod.id

    // Stock lot
    await sb.from('stock_lots').upsert({
      tenant_id: tenantId, product_id: productId, warehouse_id: warehouseId,
      lot_number: 'LOT-DEMO-001',
      qty_on_hand: qty, qty_reserved: 0,
      expired_at: addDays(expiryDays),
      received_at: addDays(-30),
      purchase_price: Math.round(price * 0.88),
      status: qty > 0 ? 'available' : 'available'
    }, { onConflict: 'tenant_id,product_id,warehouse_id,lot_number' })

    // Lot kedua (mendekati kadaluarsa) untuk beberapa item
    if (qty > 100) {
      await sb.from('stock_lots').upsert({
        tenant_id: tenantId, product_id: productId, warehouse_id: warehouseId,
        lot_number: 'LOT-DEMO-002',
        qty_on_hand: Math.round(qty * 0.12), qty_reserved: 0,
        expired_at: addDays(25),   // mendekati kadaluarsa
        received_at: addDays(-180),
        purchase_price: Math.round(price * 0.85),
        status: 'available'
      }, { onConflict: 'tenant_id,product_id,warehouse_id,lot_number' })
    }

    // Stock summary
    await sb.from('stock_summary').upsert({
      tenant_id: tenantId, product_id: productId, warehouse_id: warehouseId,
      qty_on_hand: qty, qty_reserved: 0, qty_in_transit: 0,
      avg_cost: Math.round(price * 0.88),
      nearest_expiry: addDays(expiryDays),
      last_movement_at: new Date().toISOString()
    }, { onConflict: 'tenant_id,product_id,warehouse_id' })

    // Reorder rule
    await sb.from('reorder_rules').upsert({
      tenant_id: tenantId, product_id: productId, warehouse_id: warehouseId,
      reorder_point: rop, reorder_qty: roq,
      max_stock: maxStk, lead_time_days: 7,
      safety_stock: Math.round(rop * 0.3),
      auto_create_pr: true, is_active: true
    }, { onConflict: 'tenant_id,product_id,warehouse_id' })

    ok++
    process.stdout.write(`\r   Produk: ${ok}/${PRODUCTS.length} — ${name.padEnd(35)}`)
  }

  console.log(`\n\n✅ ${ok} produk berhasil, ${skip} dilewati`)
  console.log('\n🎉 Seed inventory selesai!')
  console.log('   ⚠️  User harus LOGOUT → LOGIN ULANG agar tenant_id masuk JWT')
  console.log('   Setelah login, buka /dashboard/inventory untuk melihat data real')
}

run().catch(err => {
  console.error('❌ Fatal:', err.message)
  process.exit(1)
})

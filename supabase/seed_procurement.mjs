/**
 * TransLOG-X — Procurement Demo Seed
 * Prasyarat: seed_demo.mjs + seed_inventory.mjs sudah dijalankan
 * Membuat: 5 supplier, budget, 8 PR, 8 PO dengan lines
 *
 * Jalankan: node supabase/seed_procurement.mjs
 */
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://eccermneumcskamtitqh.supabase.co'
const SERVICE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjEzMTQ3NSwiZXhwIjoyMDk3NzA3NDc1fQ.ohQ1dVpjmYPSqoASUvRjtsLSuaAts3rhzkOQR4FdBQU'

const sb = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
})

function addDays(n) {
  const d = new Date(); d.setDate(d.getDate() + n); return d.toISOString().slice(0, 10)
}
function subDays(n) { return addDays(-n) }

async function run() {
  console.log('🌱 Seed procurement dimulai...\n')

  // ── Get tenant & warehouse ───────────────────────────────────
  const { data: tenant } = await sb.from('tenants').select('id').eq('email', 'admin@rsudemo.id').single()
  if (!tenant) { console.error('❌ Tenant tidak ditemukan'); process.exit(1) }
  const tenantId = tenant.id

  const { data: wh } = await sb.from('warehouses').select('id').eq('tenant_id', tenantId).eq('code', 'GD-UTAMA').single()
  if (!wh) { console.error('❌ Warehouse tidak ditemukan'); process.exit(1) }
  const warehouseId = wh.id

  // Get user (profile) untuk requested_by
  const { data: profile } = await sb.from('profiles').select('id').eq('tenant_id', tenantId).single()
  if (!profile) { console.error('❌ Profile tidak ditemukan'); process.exit(1) }
  const userId = profile.id

  console.log(`✅ Tenant: ${tenantId}`)
  console.log(`✅ Warehouse: ${warehouseId}`)
  console.log(`✅ User: ${userId}\n`)

  // ── Suppliers ────────────────────────────────────────────────
  const SUPPLIERS = [
    { code: 'SUP-001', name: 'PT Kimia Farma Trading & Distribution', short_name: 'Kimia Farma', type: 'pbf', city: 'Jakarta Pusat', province: 'DKI Jakarta', performance_score: 4.7, lead_time_days: 3, is_preferred: true, is_lkpp: true, payment_terms: 'net_30', cdob_certified: true, kyc_status: 'verified', status: 'active', contact_name: 'Budi Santoso', email: 'order@kimiafarma.co.id', phone: '+62218000100', credit_limit: 500000000 },
    { code: 'SUP-002', name: 'PT Enseval Putra Megatrading Tbk', short_name: 'Enseval Medika', type: 'pbf', city: 'Jakarta Timur', province: 'DKI Jakarta', performance_score: 4.3, lead_time_days: 5, is_preferred: true, is_lkpp: false, payment_terms: 'net_30', cdob_certified: true, kyc_status: 'verified', status: 'active', contact_name: 'Rina Dewi', email: 'sales@enseval.com', phone: '+62218005200', credit_limit: 300000000 },
    { code: 'SUP-003', name: 'PT Medifarma Laboratories', short_name: 'Medifarma Labs', type: 'manufacturer', city: 'Bogor', province: 'Jawa Barat', performance_score: 4.1, lead_time_days: 7, is_preferred: false, is_lkpp: false, payment_terms: 'net_45', cdob_certified: true, kyc_status: 'verified', status: 'active', contact_name: 'Agus Purnomo', email: 'b2b@medifarma.co.id', phone: '+62251400123', credit_limit: 200000000 },
    { code: 'SUP-004', name: 'PT Bernofarm', short_name: 'Bernofarm', type: 'manufacturer', city: 'Sidoarjo', province: 'Jawa Timur', performance_score: 4.5, lead_time_days: 7, is_preferred: false, is_lkpp: true, payment_terms: 'net_30', cdob_certified: true, kyc_status: 'verified', status: 'active', contact_name: 'Sari Indah', email: 'sales@bernofarm.co.id', phone: '+62318880100', credit_limit: 250000000 },
    { code: 'SUP-005', name: 'PT Kalbe Farma Tbk', short_name: 'Kalbe Farma', type: 'pbf', city: 'Jakarta Utara', province: 'DKI Jakarta', performance_score: 4.6, lead_time_days: 4, is_preferred: true, is_lkpp: true, payment_terms: 'net_30', cdob_certified: true, kyc_status: 'verified', status: 'active', contact_name: 'Hendra Wijaya', email: 'distribusi@kalbe.co.id', phone: '+62214600600', credit_limit: 400000000 },
  ]

  const supplierIds = {}
  for (const s of SUPPLIERS) {
    const { data: existing } = await sb.from('suppliers').select('id').eq('tenant_id', tenantId).eq('code', s.code).single()
    if (existing) {
      supplierIds[s.code] = existing.id
      process.stdout.write(`ℹ️  Supplier ${s.short_name} exists\n`)
    } else {
      const { data: sup, error } = await sb.from('suppliers').insert({ tenant_id: tenantId, ...s }).select('id').single()
      if (error) { console.error(`❌ Supplier ${s.name}:`, error.message); continue }
      supplierIds[s.code] = sup.id
      process.stdout.write(`✅ Supplier: ${s.short_name}\n`)
    }
  }

  // ── Budget ───────────────────────────────────────────────────
  let budgetId = null
  const { data: existBudget } = await sb.from('budgets').select('id').eq('tenant_id', tenantId).eq('period_year', 2026).eq('name', 'Anggaran Pengadaan 2026').single()
  if (existBudget) {
    budgetId = existBudget.id
    console.log('\nℹ️  Budget exists')
  } else {
    const { data: budget, error: bErr } = await sb.from('budgets').insert({
      tenant_id: tenantId, warehouse_id: warehouseId,
      name: 'Anggaran Pengadaan 2026', period_year: 2026, period_month: null,
      department: 'Farmasi', total_amount: 2400000000,
      used_amount: 387500000, reserved_amount: 250000000, status: 'active'
    }).select('id').single()
    if (bErr) { console.error('❌ Budget:', bErr.message) }
    else { budgetId = budget.id; console.log(`\n✅ Budget: ${budgetId}`) }
  }

  // ── Get products ─────────────────────────────────────────────
  const { data: products } = await sb.from('products').select('id, internal_code, name, uom_base, last_purchase_price, min_stock').eq('tenant_id', tenantId).order('internal_code')
  const pMap = {}
  for (const p of products) pMap[p.internal_code] = p

  // ── Purchase Requests ────────────────────────────────────────
  const PRS = [
    { pr_number: 'PR-2026-0012', title: 'Restock Stok Rutin Obat Bulan Juni', status: 'pending', priority: 'high', required_by: addDays(7), trigger_type: 'auto_reorder', department: 'Farmasi',
      lines: [['OBT-001',500,'tablet',850],['OBT-002',300,'kapsul',2100],['OBT-003',200,'kapsul',3200],['OBT-005',150,'tablet',2800]] },
    { pr_number: 'PR-2026-0011', title: 'Kebutuhan Mendesak IGD', status: 'approved', priority: 'critical', required_by: addDays(3), trigger_type: 'manual', department: 'IGD',
      submitted_at: subDays(5), approved_at: subDays(3),
      lines: [['OBT-015',24,'vial',145000],['ALK-001',1000,'pcs',1500],['ALK-003',50,'pcs',28000]] },
    { pr_number: 'PR-2026-0010', title: 'Restock Obat Kronik Poli Umum', status: 'approved', priority: 'medium', required_by: addDays(10), trigger_type: 'manual', department: 'Poli Umum',
      submitted_at: subDays(8), approved_at: subDays(6),
      lines: [['OBT-004',400,'tablet',1500],['OBT-010',300,'tablet',2200],['OBT-011',250,'tablet',3100],['OBT-014',100,'tablet',3500]] },
    { pr_number: 'PR-2026-0009', title: 'Penambahan Stok Alkes & BMHP', status: 'rejected', priority: 'medium', required_by: addDays(14), trigger_type: 'manual', department: 'Farmasi',
      submitted_at: subDays(13), rejected_reason: 'Budget bulan ini sudah terpakai >80%. Ajukan bulan depan.',
      lines: [['ALK-002',400,'set',8500],['BMH-001',100,'botol',32000],['BMH-002',500,'pcs',1200]] },
    { pr_number: 'PR-2026-0008', title: 'Reagensia Laboratorium Bulanan', status: 'approved', priority: 'high', required_by: addDays(5), trigger_type: 'scheduled', department: 'Laboratorium',
      submitted_at: subDays(18), approved_at: subDays(16),
      lines: [['REG-001',200,'strip',6000],['REG-002',100,'test',85000]] },
    { pr_number: 'PR-2026-0007', title: 'Stock Opname — Item Kadaluarsa Dekat', status: 'draft', priority: 'low', required_by: addDays(21), trigger_type: 'manual', department: 'Farmasi',
      lines: [['OBT-007',200,'tablet',4500],['OBT-008',300,'tablet',1800]] },
    { pr_number: 'PR-2026-0006', title: 'Emergency — Insulin Glargine Habis', status: 'approved', priority: 'high', required_by: addDays(1), trigger_type: 'min_stock', department: 'ICU',
      submitted_at: subDays(2), approved_at: subDays(1),
      lines: [['OBT-015',50,'vial',145000]] },
    { pr_number: 'PR-2026-0005', title: 'Masker & APD Operasional', status: 'approved', priority: 'medium', required_by: addDays(10), trigger_type: 'manual', department: 'Farmasi',
      submitted_at: subDays(20), approved_at: subDays(18),
      lines: [['ALK-004',2000,'pcs',850],['ALK-005',500,'pasang',3500]] },
  ]

  const prIds = {}
  for (const pr of PRS) {
    const { data: existing } = await sb.from('purchase_requests').select('id').eq('tenant_id', tenantId).eq('pr_number', pr.pr_number).single()
    if (existing) { prIds[pr.pr_number] = existing.id; continue }

    const lines = pr.lines
    const totalEst = lines.reduce((sum, [,qty,,price]) => sum + qty * price, 0)

    const { data: newPR, error: prErr } = await sb.from('purchase_requests').insert({
      tenant_id: tenantId, warehouse_id: warehouseId, budget_id: budgetId,
      pr_number: pr.pr_number, title: pr.title, status: pr.status,
      priority: pr.priority, required_by: pr.required_by,
      total_est_value: totalEst, trigger_type: pr.trigger_type,
      requested_by: userId,
      submitted_at: pr.submitted_at ?? null,
      approved_by: pr.approved_at ? userId : null,
      approved_at: pr.approved_at ?? null,
      rejected_reason: pr.rejected_reason ?? null,
      metadata: { department: pr.department ?? 'Farmasi' }
    }).select('id').single()
    if (prErr) { console.error(`❌ PR ${pr.pr_number}:`, prErr.message); continue }
    prIds[pr.pr_number] = newPR.id

    for (const [code, qty, uom, price] of lines) {
      const prod = pMap[code]
      if (!prod) continue
      await sb.from('purchase_request_lines').insert({
        tenant_id: tenantId, pr_id: newPR.id, product_id: prod.id,
        qty_requested: qty, uom, est_unit_price: price, est_total: qty * price
      })
    }
    process.stdout.write(`✅ PR: ${pr.pr_number} (${pr.status})\n`)
  }

  // ── Purchase Orders ──────────────────────────────────────────
  const POS = [
    { po_number: 'PO-2026-0048', supplier: 'SUP-001', pr: 'PR-2026-0011', status: 'sent_to_supplier', priority: 'critical',
      order_date: subDays(4), expected_delivery: addDays(2), payment_terms: 'net_30',
      lines: [['OBT-015',24,'vial',128000],['ALK-001',1000,'pcs',1400],['ALK-003',50,'pcs',26000]] },
    { po_number: 'PO-2026-0047', supplier: 'SUP-002', pr: 'PR-2026-0008', status: 'approved', priority: 'high',
      order_date: subDays(15), expected_delivery: addDays(1), payment_terms: 'net_30',
      lines: [['REG-001',200,'strip',5800],['REG-002',100,'test',82000]] },
    { po_number: 'PO-2026-0046', supplier: 'SUP-001', pr: 'PR-2026-0010', status: 'partially_received', priority: 'medium',
      order_date: subDays(7), expected_delivery: subDays(1), payment_terms: 'net_30',
      lines: [['OBT-004',400,'tablet',1400],['OBT-010',300,'tablet',2100],['OBT-011',250,'tablet',2950]] },
    { po_number: 'PO-2026-0045', supplier: 'SUP-003', pr: 'PR-2026-0005', status: 'sent_to_supplier', priority: 'medium',
      order_date: subDays(6), expected_delivery: addDays(6), payment_terms: 'net_30',
      lines: [['ALK-004',2000,'pcs',820],['ALK-005',500,'pasang',3400]] },
    { po_number: 'PO-2026-0044', supplier: 'SUP-004', pr: 'PR-2026-0010', status: 'fully_received', priority: 'medium',
      order_date: subDays(25), expected_delivery: subDays(15), payment_terms: 'net_30',
      lines: [['OBT-014',100,'tablet',3200]] },
    { po_number: 'PO-2026-0043', supplier: 'SUP-005', pr: 'PR-2026-0006', status: 'sent_to_supplier', priority: 'high',
      order_date: subDays(1), expected_delivery: addDays(1), payment_terms: 'net_30',
      lines: [['OBT-015',50,'vial',138000]] },
    { po_number: 'PO-2026-0042', supplier: 'SUP-001', pr: null, status: 'approved', priority: 'low',
      order_date: subDays(3), expected_delivery: addDays(5), payment_terms: 'net_30',
      lines: [['OBT-001',1000,'tablet',810],['OBT-006',400,'tablet',1150],['OBT-012',600,'tablet',1550]] },
    { po_number: 'PO-2026-0041', supplier: 'SUP-002', pr: null, status: 'draft', priority: 'medium',
      order_date: subDays(1), expected_delivery: addDays(8), payment_terms: 'net_45',
      lines: [['ALK-002',200,'set',8200],['BMH-002',500,'pcs',1150],['BMH-003',100,'roll',17000]] },
  ]

  for (const po of POS) {
    const { data: existing } = await sb.from('purchase_orders').select('id').eq('tenant_id', tenantId).eq('po_number', po.po_number).single()
    if (existing) { process.stdout.write(`ℹ️  PO ${po.po_number} exists\n`); continue }

    const supId = supplierIds[po.supplier]
    const prId  = po.pr ? prIds[po.pr] : null

    const subtotal = po.lines.reduce((sum, [,qty,,price]) => sum + qty * price, 0)
    const tax = Math.round(subtotal * 0.11)
    const total = subtotal + tax

    const isSubmitted = ['sent_to_supplier','approved','partially_received','fully_received'].includes(po.status)
    const { data: newPO, error: poErr } = await sb.from('purchase_orders').insert({
      tenant_id: tenantId, supplier_id: supId, warehouse_id: warehouseId,
      budget_id: budgetId, pr_id: prId,
      po_number: po.po_number, status: po.status, priority: po.priority,
      order_date: po.order_date, expected_delivery: po.expected_delivery,
      payment_terms: po.payment_terms,
      subtotal, tax_amount: tax, total_amount: total, currency: 'IDR',
      submitted_by: isSubmitted ? userId : null,
      submitted_at: isSubmitted ? new Date(Date.now() - 86400000).toISOString() : null,
      approved_by: isSubmitted ? userId : null,
      approved_at: isSubmitted ? new Date(Date.now() - 82800000).toISOString() : null,
      sent_at: ['sent_to_supplier','partially_received','fully_received'].includes(po.status) ? new Date(Date.now() - 79200000).toISOString() : null,
      created_by: userId, metadata: {}
    }).select('id').single()
    if (poErr) { console.error(`❌ PO ${po.po_number}:`, poErr.message); continue }

    for (const [code, qty, uom, price] of po.lines) {
      const prod = pMap[code]
      if (!prod) continue
      const qtyReceived = po.status === 'fully_received' ? qty : po.status === 'partially_received' ? Math.round(qty * 0.6) : 0
      const lineTotal = Math.round(qty * price * 1.11)
      await sb.from('po_lines').insert({
        tenant_id: tenantId, po_id: newPO.id, product_id: prod.id,
        qty_ordered: qty, qty_received: qtyReceived, uom,
        unit_price: price, discount_pct: 0, tax_pct: 11, line_total: lineTotal
      })
    }
    process.stdout.write(`✅ PO: ${po.po_number} (${po.status})\n`)
  }

  // ── Supplier Products ────────────────────────────────────────
  console.log('\n🔗 Linking supplier products...')
  const spLinks = [
    ['SUP-001', 'OBT-001', 810,  'tablet', 30], ['SUP-001', 'OBT-002', 1980, 'kapsul', 60],
    ['SUP-001', 'OBT-015', 138000,'vial',  14], ['SUP-001', 'ALK-001', 1400, 'pcs',    14],
    ['SUP-001', 'ALK-003', 26000,'pcs',    21], ['SUP-002', 'REG-001', 5800, 'strip',  30],
    ['SUP-002', 'REG-002', 82000,'test',   21], ['SUP-002', 'ALK-002', 8200, 'set',    14],
    ['SUP-003', 'ALK-004', 820,  'pcs',    30], ['SUP-003', 'ALK-005', 3400, 'pasang', 30],
    ['SUP-004', 'OBT-014', 3200, 'tablet', 60], ['SUP-004', 'OBT-007', 4300, 'tablet', 45],
    ['SUP-005', 'OBT-015', 136000,'vial',  14], ['SUP-005', 'OBT-004', 1400, 'tablet', 45],
  ]
  let spOk = 0
  for (const [sCode, pCode, price, uom, lead] of spLinks) {
    const supId = supplierIds[sCode]
    const prod  = pMap[pCode]
    if (!supId || !prod) continue
    const { error } = await sb.from('supplier_products').upsert({
      tenant_id: tenantId, supplier_id: supId, product_id: prod.id,
      unit_price: price, currency: 'IDR', uom, min_order_qty: 1, lead_time_days: lead,
      is_active: true, price_valid_until: addDays(90)
    }, { onConflict: 'tenant_id,supplier_id,product_id' })
    if (!error) spOk++
  }
  console.log(`✅ ${spOk} supplier-product links`)

  console.log('\n🎉 Seed procurement selesai!')
  console.log('   Buka /dashboard/procurement untuk melihat data')
}

run().catch(err => { console.error('❌ Fatal:', err.message); process.exit(1) })

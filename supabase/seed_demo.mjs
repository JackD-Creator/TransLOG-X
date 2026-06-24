// =============================================================================
// TransLOG-X — SEED DEMO STAKEHOLDER
// HAPUS data lama → seed fresh: 10 RS · 5 Distributor · Jan-Mei 2026
// KSM: PT. Trisprima Usaha Jaya
// Ratusan item obat/BMHP/alkes dari KFA real
// =============================================================================
import { createClient } from '@supabase/supabase-js'

const sb = createClient(
  'https://eccermneumcskamtitqh.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjEzMTQ3NSwiZXhwIjoyMDk3NzA3NDc1fQ.ohQ1dVpjmYPSqoASUvRjtsLSuaAts3rhzkOQR4FdBQU',
  { auth: { autoRefreshToken: false, persistSession: false } }
)

const KSM_ID  = 'de0a6815-7098-45ce-b682-1c16def8e154'
const BANK_ID = '4aa64caa-a1c3-4569-93dd-07487cbca252'

const RS_LIST = [
  { name: 'RSUP Dr. Cipto Mangunkusumo Unggul', city: 'Jakarta Pusat',   kelas: 'A', monthlyMin: 10e9, monthlyMax: 12e9 },
  { name: 'RSUP Fatmawati Unggul',              city: 'Jakarta Selatan', kelas: 'A', monthlyMin: 10e9, monthlyMax: 12e9 },
  { name: 'RSUD Pasar Rebo Unggul',             city: 'Jakarta Timur',   kelas: 'B', monthlyMin: 5e9,  monthlyMax: 8e9 },
  { name: 'RSUD Budhi Asih Unggul',             city: 'Jakarta Timur',   kelas: 'B', monthlyMin: 5e9,  monthlyMax: 8e9 },
  { name: 'RSUD Cengkareng Unggul',             city: 'Jakarta Barat',   kelas: 'B', monthlyMin: 5e9,  monthlyMax: 8e9 },
  { name: 'RSUD Koja Unggul',                   city: 'Jakarta Utara',   kelas: 'C', monthlyMin: 2e9,  monthlyMax: 3e9 },
  { name: 'RSUD Tarakan Unggul',                city: 'Jakarta Pusat',   kelas: 'C', monthlyMin: 2e9,  monthlyMax: 3e9 },
  { name: 'RSUD Duren Sawit Unggul',            city: 'Jakarta Timur',   kelas: 'C', monthlyMin: 2e9,  monthlyMax: 3e9 },
  { name: 'RSUD Jati Padang Unggul',            city: 'Jakarta Selatan', kelas: 'C', monthlyMin: 2e9,  monthlyMax: 3e9 },
  { name: 'RSUD Cipayung Unggul',               city: 'Jakarta Timur',   kelas: 'D', monthlyMin: 500e6, monthlyMax: 1e9 },
]

const DIST_LIST = [
  { name: 'PT Kimia Farma Trading & Distribution', city: 'Jakarta',  focus: 'obat' },
  { name: 'PT Enseval Putra Megatrading Tbk',      city: 'Jakarta',  focus: 'obat' },
  { name: 'PT Kalbe Farma Tbk',                    city: 'Jakarta',  focus: 'obat' },
  { name: 'PT Bina San Prima',                     city: 'Jakarta',  focus: 'obat' },
  { name: 'PT Jayamas Medica Industri',             city: 'Sidoarjo', focus: 'bmhp' },
]

const MONTHS = ['2026-01','2026-02','2026-03','2026-04','2026-05']

function rand(a, b) { return a + Math.random() * (b - a) }
function randInt(a, b) { return Math.floor(rand(a, b + 1)) }
function pick(arr) { return arr[Math.floor(Math.random() * arr.length)] }
function pickN(arr, n) { const s = [...arr].sort(() => Math.random() - 0.5); return s.slice(0, Math.min(n, s.length)) }

async function seed() {
  console.log('🧹 CLEANUP data lama...\n')
  for (const t of ['daily_interest_accruals','ksm_invoices','ar_accounts','ksm_po_lines','ksm_purchase_orders','hospital_notification_lines','hospital_notifications','standing_instructions','supplier_catalog_items','supplier_item_mapping','ksm_catalog_items','scf_facilities']) {
    const { error } = await sb.from(t).delete().neq('id', '00000000-0000-0000-0000-000000000000')
    console.log(`  ${error ? '✗ '+t+': '+error.message : '✓ '+t}`)
  }
  await sb.from('tenants').delete().not('id', 'in', `("${KSM_ID}","${BANK_ID}")`)
  console.log('  ✓ tenants (keep KSM+Bank)\n')

  // ── KSM ─────────────────────────────────────────────────────────────────
  await sb.from('tenants').update({ name: 'PT. Trisprima Usaha Jaya' }).eq('id', KSM_ID)
  console.log('✅ KSM: PT. Trisprima Usaha Jaya')

  // ── RS ──────────────────────────────────────────────────────────────────
  const rsIds = []
  for (const rs of RS_LIST) {
    const { data: t, error } = await sb.from('tenants').insert({
      name: rs.name, type: 'rs_pemerintah', status: 'active', city: rs.city, kelas_rs: rs.kelas,
      email: rs.name.toLowerCase().replace(/[^a-z]/g, '').slice(0, 20) + '@rs.go.id',
      metadata: { kelas: rs.kelas, monthly_min: rs.monthlyMin, monthly_max: rs.monthlyMax }
    }).select('id').single()
    if (error) { console.log(`  ✗ ${rs.name}: ${error.message}`); continue }
    rsIds.push(t.id)
    console.log(`  ✅ ${rs.name} (${rs.kelas})`)
  }

  // ── Distributor ─────────────────────────────────────────────────────────
  const distIds = []
  for (const d of DIST_LIST) {
    const { data: t, error } = await sb.from('tenants').insert({
      name: d.name, type: 'distributor', status: 'active', city: d.city,
      email: d.name.toLowerCase().replace(/[^a-z]/g, '').slice(0, 20) + '@dist.co.id',
      metadata: { focus: d.focus }
    }).select('id').single()
    if (error) { console.log(`  ✗ ${d.name}: ${error.message}`); continue }
    distIds.push(t.id)
    console.log(`  ✅ ${d.name}`)
  }

  // ── Load KFA (banyak item) ──────────────────────────────────────────────
  console.log('\n📦 Loading KFA...')
  const { data: drugs } = await sb.from('kfa_drugs')
    .select('kfa_code,name,fix_price,uom,manufacturer,distributor,kelas_terapi,is_fornas')
    .not('fix_price','is',null).gt('fix_price', 200).lt('fix_price', 5000000).limit(500)
  const { data: alkes } = await sb.from('kfa_alkes')
    .select('kfa_code,name,fix_price,uom,manufacturer,distributor')
    .not('fix_price','is',null).gt('fix_price', 500).lt('fix_price', 10000000).limit(200)

  const obatPool = (drugs ?? []).filter(d => d.fix_price > 0)
  const alkesPool = (alkes ?? []).filter(d => d.fix_price > 0)
  // BMHP = obat murah (< Rp50.000) sebagai proxy consumables
  const bmhpPool = obatPool.filter(o => Number(o.fix_price) < 50000)
  const obatMedium = obatPool.filter(o => Number(o.fix_price) >= 5000 && Number(o.fix_price) <= 500000)
  const obatHigh = obatPool.filter(o => Number(o.fix_price) > 500000)

  console.log(`  Obat: ${obatPool.length} (medium: ${obatMedium.length}, high: ${obatHigh.length})`)
  console.log(`  BMHP: ${bmhpPool.length}`)
  console.log(`  Alkes: ${alkesPool.length}`)

  // ── Supplier catalog (banyak item per dist) ─────────────────────────────
  for (let di = 0; di < distIds.length; di++) {
    const d = DIST_LIST[di]
    const pool = d.focus === 'bmhp' ? [...alkesPool, ...bmhpPool] : obatPool
    const items = pickN(pool, Math.min(80, pool.length))
    const catItems = items.map(item => ({
      tenant_id: distIds[di], kfa_code: item.kfa_code,
      catalog_type: d.focus === 'bmhp' ? (alkesPool.includes(item) ? 'alkes' : 'bmhp') : 'obat',
      name: item.name, manufacturer: item.manufacturer ?? d.name,
      uom: item.uom || 'tablet',
      hna_price: Math.round(Number(item.fix_price) * rand(1.05, 1.10)),
      sell_price: Math.round(Number(item.fix_price) * rand(1.10, 1.18)),
      min_order_qty: 10, stock_available: randInt(200, 5000),
      lead_time_days: randInt(2, 5), payment_terms: 'net_30', is_available: true,
      metadata: { distributor_name: d.name, distributor_id: distIds[di] }
    }))
    await sb.from('supplier_catalog_items').upsert(catItems, { onConflict: 'tenant_id,kfa_code', ignoreDuplicates: true })
    console.log(`  📦 ${d.name}: ${catItems.length} items`)
  }

  // ── SCF + SI ────────────────────────────────────────────────────────────
  for (let i = 0; i < rsIds.length; i++) {
    const rs = RS_LIST[i]
    const limit = Math.round(((rs.monthlyMin + rs.monthlyMax) / 2) * 4)
    await sb.from('scf_facilities').insert({
      bank_tenant_id: BANK_ID, borrower_tenant_id: KSM_ID,
      facility_number: `SCF-${rs.kelas}-${String(i+1).padStart(3,'0')}`,
      financing_type: 'reverse_factoring', facility_limit: limit,
      outstanding: Math.round(limit * rand(0.15, 0.45)),
      interest_rate_pa: 0.1100, tenor_days: 30, payment_terms: 'net_30',
      status: 'approved', facility_start: '2026-01-01', facility_end: '2026-12-31',
      approved_at: '2026-01-01T00:00:00Z', standing_instruction_active: true,
      metadata: { rs_name: rs.name, rs_kelas: rs.kelas }
    })
    await sb.from('standing_instructions').insert({
      rs_tenant_id: rsIds[i], bank_tenant_id: BANK_ID, ksm_tenant_id: KSM_ID,
      si_number: `SI-RS-${String(i+1).padStart(3,'0')}`, si_type: 'bpjs_auto_transfer',
      rs_account_number: `BCA-${1000+i}`, ksm_account_number: 'BCA-KSM-001',
      custodian_bank: 'Bank Central Asia (BCA)', is_active: true, activated_at: '2026-01-01T00:00:00Z',
    })
  }
  console.log(`\n✅ ${rsIds.length} SCF + SI`)

  // ── POs Jan-Mei 2026 (RATUSAN item per bulan) ───────────────────────────
  let poSeq = 1, totalPOs = 0, totalValue = 0

  for (const monthKey of MONTHS) {
    const monthNum = parseInt(monthKey.split('-')[1])
    let monthPOs = 0, monthVal = 0

    for (let i = 0; i < rsIds.length; i++) {
      const rs = RS_LIST[i]
      const monthlyVol = rand(rs.monthlyMin, rs.monthlyMax)

      // Jumlah PO per bulan: Tipe A=6-8, B=4-5, C=3-4, D=2
      const poCount = rs.kelas === 'A' ? randInt(6,8) : rs.kelas === 'B' ? randInt(4,5) : rs.kelas === 'C' ? randInt(3,4) : 2

      for (let p = 0; p < poCount; p++) {
        const distIdx = p % distIds.length
        const poVol = monthlyVol / poCount

        const lines = []

        // OBAT: 70% budget, 15-30 items per PO (realistis untuk RS)
        const obatBudget = poVol * 0.70
        const obatLineCount = rs.kelas === 'A' ? randInt(25, 40) : rs.kelas === 'B' ? randInt(18, 30) : randInt(12, 20)
        const obatSelection = pickN(obatPool, obatLineCount)
        for (const item of obatSelection) {
          const price = Math.round(Number(item.fix_price) * rand(1.06, 1.15))
          const qty = Math.max(5, Math.round(obatBudget / obatLineCount / price * rand(0.5, 1.5)))
          lines.push({ kfa_code: item.kfa_code, item_name: item.name, catalog_type: 'obat', uom: item.uom || 'tablet', ordered_qty: qty, unit_price: price, line_total: qty * price, received_qty: 0 })
        }

        // BMHP: 25% budget, 8-15 items (sarung tangan, masker, infus set, dll)
        const bmhpBudget = poVol * 0.25
        const bmhpLineCount = rs.kelas === 'A' ? randInt(10, 18) : rs.kelas === 'B' ? randInt(8, 12) : randInt(5, 10)
        const bmhpSelection = pickN(bmhpPool, bmhpLineCount)
        for (const item of bmhpSelection) {
          const price = Math.round(Number(item.fix_price) * rand(1.05, 1.12))
          const qty = Math.max(20, Math.round(bmhpBudget / bmhpLineCount / price * rand(0.6, 1.4)))
          lines.push({ kfa_code: item.kfa_code, item_name: item.name, catalog_type: 'bmhp', uom: item.uom || 'box', ordered_qty: qty, unit_price: price, line_total: qty * price, received_qty: 0 })
        }

        // ALKES: 5% budget, 2-5 items (tensimeter, nebulizer, dll)
        const alkesBudget = poVol * 0.05
        const alkesLineCount = randInt(2, 5)
        const alkesSelection = pickN(alkesPool, alkesLineCount)
        for (const item of alkesSelection) {
          const price = Math.round(Number(item.fix_price) * rand(1.08, 1.22))
          const qty = Math.max(1, Math.round(alkesBudget / alkesLineCount / price * rand(0.5, 1.5)))
          lines.push({ kfa_code: item.kfa_code, item_name: item.name, catalog_type: 'alkes', uom: item.uom || 'unit', ordered_qty: qty, unit_price: price, line_total: qty * price, received_qty: 0 })
        }

        const subtotal = lines.reduce((s, l) => s + l.line_total, 0)
        const tax = Math.round(subtotal * 0.11)
        const total = subtotal + tax
        const isSCF = Math.random() < 0.80

        // Status realistis per bulan
        let status
        if (monthNum <= 2) status = 'fully_received'
        else if (monthNum === 3) status = Math.random() < 0.7 ? 'fully_received' : (Math.random() < 0.5 ? 'sent_to_supplier' : 'partially_received')
        else if (monthNum === 4) { const r = Math.random(); status = r < 0.25 ? 'fully_received' : r < 0.5 ? 'sent_to_supplier' : r < 0.75 ? 'approved' : 'submitted' }
        else { const r = Math.random(); status = r < 0.15 ? 'sent_to_supplier' : r < 0.4 ? 'approved' : r < 0.7 ? 'submitted' : 'draft' }

        if (status === 'fully_received') lines.forEach(l => { l.received_qty = l.ordered_qty })
        else if (status === 'partially_received') lines.forEach(l => { l.received_qty = Math.floor(l.ordered_qty * rand(0.4, 0.85)) })

        const poDate = `${monthKey}-${String(randInt(1, 25)).padStart(2, '0')}`
        const poNumber = `KSM-PO-2026-${String(poSeq++).padStart(5, '0')}`

        const { data: po, error: poErr } = await sb.from('ksm_purchase_orders').insert({
          ksm_tenant_id: KSM_ID, supplier_tenant_id: distIds[distIdx], rs_tenant_id: rsIds[i],
          po_number: poNumber, po_date: poDate,
          expected_delivery: new Date(new Date(poDate).getTime() + randInt(3,7)*86400000).toISOString().slice(0,10),
          status, payment_terms: isSCF ? 'net_30' : 'net_45',
          subtotal, tax_amount: tax, total_amount: total,
          submitted_at: status !== 'draft' ? new Date(poDate).toISOString() : null,
          metadata: { rs_name: rs.name, rs_address: rs.city, supplier_name: DIST_LIST[distIdx].name, payment_method: isSCF ? 'scf' : 'termin' }
        }).select('id').single()

        if (poErr) { console.log(`  ✗ PO: ${poErr.message}`); continue }

        // Batch insert lines (bisa 30-60 lines per PO)
        await sb.from('ksm_po_lines').insert(lines.map(l => ({ ...l, po_id: po.id })))

        totalPOs++; totalValue += total; monthPOs++; monthVal += total

        // Invoice + AR untuk fully_received
        if (status === 'fully_received') {
          const invDate = new Date(new Date(poDate).getTime() + 1*86400000) // H+1
          const invDueDate = new Date(invDate.getTime() + 30*86400000)
          const invNumber = `INV-KSM-2026-${String(poSeq).padStart(5,'0')}`

          // Tentukan status invoice & pembayaran berdasarkan bulan
          let invStatus = 'sent_to_rs', invPaid = 0, bpjsAmt = null, bpjsDate = null, shortfall = 0, shortfallBank = false
          if (monthNum <= 2) {
            invStatus = 'paid'; invPaid = total
            bpjsAmt = total; bpjsDate = new Date(invDate.getTime() + randInt(15,25)*86400000).toISOString().slice(0,10)
          } else if (monthNum === 3) {
            if (Math.random() < 0.5) {
              invStatus = 'paid'; invPaid = total; bpjsAmt = total
              bpjsDate = new Date(invDate.getTime() + randInt(15,25)*86400000).toISOString().slice(0,10)
            } else if (Math.random() < 0.5) {
              // Partially paid — BPJS kurang, ada shortfall
              bpjsAmt = Math.round(total * rand(0.7, 0.9))
              invPaid = bpjsAmt; shortfall = total - bpjsAmt; shortfallBank = true
              invStatus = 'partially_paid'
              bpjsDate = new Date(invDate.getTime() + randInt(20,30)*86400000).toISOString().slice(0,10)
            } else {
              invStatus = 'payment_pending'
            }
          } else if (monthNum === 4) {
            invStatus = Math.random() < 0.4 ? 'payment_pending' : 'sent_to_rs'
          }

          // Buat ksm_invoices
          await sb.from('ksm_invoices').insert({
            ksm_tenant_id: KSM_ID, rs_tenant_id: rsIds[i], po_id: po.id,
            invoice_number: invNumber, invoice_date: invDate.toISOString().slice(0,10),
            due_date: invDueDate.toISOString().slice(0,10),
            subtotal, tax_amount: tax, total_amount: total,
            status: invStatus, paid_amount: invPaid, contract_payment_days: 30,
            bpjs_amount: bpjsAmt, bpjs_received_date: bpjsDate,
            shortfall_amount: shortfall, shortfall_covered_by_bank: shortfallBank,
            reviewed_at: new Date(invDate.getTime() + 86400000).toISOString(),
            sent_to_rs_at: invStatus !== 'draft' ? new Date(invDate.getTime() + 2*86400000).toISOString() : null,
            metadata: { po_number: poNumber, rs_name: rs.name, supplier_name: DIST_LIST[distIdx].name, auto_generated: true }
          })

          // AR (Bank→Distributor) untuk SCF POs
          if (isSCF) {
            const disbDate = new Date(new Date(poDate).getTime() + 2*86400000)
            const arDueDate = new Date(disbDate.getTime() + 30*86400000)
            const interest = Math.round(total * 0.11 / 12)
            const totalPayable = total + interest
            let arStatus = 'disbursed', arPaid = 0
            if (monthNum <= 2) { arStatus = 'paid'; arPaid = totalPayable }
            else if (monthNum === 3 && Math.random() < 0.6) { arStatus = 'paid'; arPaid = totalPayable }

            await sb.from('ar_accounts').insert({
              bank_tenant_id: BANK_ID, ksm_tenant_id: KSM_ID,
              ar_number: `AR-${poNumber.slice(-5)}`, po_number: poNumber,
              invoice_ref: invNumber,
              invoice_amount: total, disbursed_amount: total,
              interest_amount: interest, total_payable: totalPayable, paid_amount: arPaid,
              invoice_date: disbDate.toISOString().slice(0,10),
              disbursement_date: disbDate.toISOString().slice(0,10),
              due_date: arDueDate.toISOString().slice(0,10),
              paid_date: arStatus === 'paid' ? arDueDate.toISOString().slice(0,10) : null,
              status: arStatus,
            })
          }
        }
      }
    }
    console.log(`\n📅 ${monthKey}: ${monthPOs} PO, Rp ${(monthVal/1e9).toFixed(1)} Miliar`)
  }

  // ── Notifikasi SIMRS demo ───────────────────────────────────────────────
  const notifCfg = [
    { st: 'pending', sc: null, kc: null, urg: 'critical' },
    { st: 'pending', sc: null, kc: null, urg: 'critical' },
    { st: 'acknowledged', sc: 'checking', kc: null, urg: 'high' },
    { st: 'acknowledged', sc: 'confirmed', kc: 'pending_rs_approval', urg: 'high' },
    { st: 'po_created', sc: 'confirmed', kc: 'rs_approved', urg: 'normal' },
    { st: 'completed', sc: 'confirmed', kc: 'rs_approved', urg: 'normal' },
  ]
  for (let n = 0; n < notifCfg.length; n++) {
    const ri = n % rsIds.length, rs = RS_LIST[ri], c = notifCfg[n]
    const { data: notif } = await sb.from('hospital_notifications').insert({
      rs_tenant_id: rsIds[ri], ksm_tenant_id: KSM_ID,
      notif_number: `NOTIF-DEMO-${String(n+1).padStart(3,'0')}`,
      notif_date: `2026-05-${String(20+n).padStart(2,'0')}`, source: 'simrs',
      status: c.st, ksm_confirmation_status: c.kc,
      notes: `SIMRS Alert: stok kritis ${rs.name}`,
      metadata: { rs_name: rs.name, rs_address: rs.city, urgency: c.urg, supplier_check: c.sc, ...(c.sc==='confirmed'?{supplier_confirmed_at:'2026-05-22T10:00:00Z'}:{}) }
    }).select('id').single()
    if (notif) {
      const nLines = pickN(obatPool, randInt(8, 15)).map((item, li) => ({
        notification_id: notif.id, kfa_code: item.kfa_code, item_name: item.name,
        catalog_type: li < 10 ? 'obat' : 'bmhp', uom: item.uom || 'tablet',
        current_stock: randInt(0, 25), min_stock: randInt(40, 120), requested_qty: randInt(50, 800),
      }))
      await sb.from('hospital_notification_lines').insert(nLines)
    }
  }
  console.log(`\n✅ 6 Notifikasi SIMRS`)

  console.log('\n' + '='.repeat(60))
  console.log('🎉 SEED DEMO SELESAI')
  console.log(`   ${rsIds.length} RS · ${distIds.length} Dist · ${totalPOs} POs`)
  console.log(`   Total: Rp ${(totalValue/1e9).toFixed(1)} Miliar (Jan-Mei 2026)`)
  console.log('='.repeat(60))
}

seed().catch(e => { console.error('Fatal:', e.message); process.exit(1) })

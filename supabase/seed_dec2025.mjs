// =============================================================================
// TransLOG-X — SEED DESEMBER 2025
// Tambah data Desember 2025 agar laporan Januari 2026 tampil (offset -1 bulan)
// TIDAK menghapus data existing — hanya INSERT baru
// =============================================================================
import { createClient } from '@supabase/supabase-js'

const sb = createClient(
  'https://eccermneumcskamtitqh.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjEzMTQ3NSwiZXhwIjoyMDk3NzA3NDc1fQ.ohQ1dVpjmYPSqoASUvRjtsLSuaAts3rhzkOQR4FdBQU',
  { auth: { autoRefreshToken: false, persistSession: false } }
)

const KSM_ID  = 'de0a6815-7098-45ce-b682-1c16def8e154'
const BANK_ID = '4aa64caa-a1c3-4569-93dd-07487cbca252'

function rand(a, b) { return a + Math.random() * (b - a) }
function randInt(a, b) { return Math.floor(rand(a, b + 1)) }
function pick(arr) { return arr[Math.floor(Math.random() * arr.length)] }
function pickN(arr, n) { const s = [...arr].sort(() => Math.random() - 0.5); return s.slice(0, Math.min(n, s.length)) }

async function seed() {
  console.log('📅 SEED DESEMBER 2025\n')

  // ── Load existing RS + Distributor tenants ──────────────────────────────
  const { data: allTenants } = await sb.from('tenants').select('id,name,type,metadata')
  const rsArr   = (allTenants ?? []).filter(t => t.type === 'rs_pemerintah' && t.metadata?.monthly_min)
  const distArr = (allTenants ?? []).filter(t => t.type === 'distributor')

  if (rsArr.length === 0) { console.error('❌ Tidak ada RS tenant. Jalankan seed_demo.mjs dulu!'); process.exit(1) }
  console.log(`✅ ${rsArr.length} RS, ${distArr.length} Distributor ditemukan\n`)

  // ── Load SCF facilities + Standing Instructions ─────────────────────────
  const { data: scfData } = await sb.from('scf_facilities')
    .select('id,interest_rate_pa,borrower_tenant_id')
    .eq('borrower_tenant_id', KSM_ID).eq('status', 'approved')
  const scfFacility = scfData?.[0] ?? null

  // ── Load KFA items ──────────────────────────────────────────────────────
  const { data: drugs } = await sb.from('kfa_drugs')
    .select('kfa_code,name,fix_price,uom').not('fix_price','is',null)
    .gt('fix_price', 200).lt('fix_price', 5000000).limit(400)
  const { data: alkes } = await sb.from('kfa_alkes')
    .select('kfa_code,name,fix_price,uom').not('fix_price','is',null)
    .gt('fix_price', 500).lt('fix_price', 10000000).limit(100)

  const obatPool = (drugs ?? []).filter(d => d.fix_price > 0)
  const alkesPool = (alkes ?? []).filter(d => d.fix_price > 0)
  const bmhpPool  = obatPool.filter(o => Number(o.fix_price) < 50000)
  console.log(`📦 Pool: ${obatPool.length} obat, ${bmhpPool.length} bmhp, ${alkesPool.length} alkes\n`)

  // ── Cari sequence terakhir PO + Invoice ────────────────────────────────
  const { data: lastPO } = await sb.from('ksm_purchase_orders')
    .select('po_number').order('po_number', { ascending: false }).limit(1)
  const { data: lastInv } = await sb.from('ksm_invoices')
    .select('invoice_number').order('invoice_number', { ascending: false }).limit(1)

  let poSeq   = 300 // mulai dari 300 agar tidak collision dengan existing
  let invSeq  = 300

  // Ambil angka dari existing sequence
  if (lastPO?.[0]?.po_number) {
    const n = parseInt(lastPO[0].po_number.replace(/\D/g, '').slice(-5))
    if (n >= poSeq) poSeq = n + 1
  }
  if (lastInv?.[0]?.invoice_number) {
    const n = parseInt(lastInv[0].invoice_number.replace(/\D/g, '').slice(-5))
    if (n >= invSeq) invSeq = n + 1
  }
  console.log(`📝 PO sequence mulai: ${poSeq}, Invoice mulai: ${invSeq}\n`)

  // ── Generate PO Desember 2025 ───────────────────────────────────────────
  let totalPOs = 0, totalInvs = 0, totalValue = 0

  for (let i = 0; i < rsArr.length; i++) {
    const rs = rsArr[i]
    const monthlyMin = rs.metadata?.monthly_min ?? 2e9
    const monthlyMax = rs.metadata?.monthly_max ?? 5e9
    const kelas = rs.metadata?.kelas ?? 'C'
    const monthlyVol = rand(monthlyMin, monthlyMax)

    // Jumlah PO per bulan berdasarkan kelas RS
    const poCount = kelas === 'A' ? randInt(6,8) : kelas === 'B' ? randInt(4,5) : kelas === 'C' ? randInt(3,4) : 2

    for (let p = 0; p < poCount; p++) {
      const distIdx = p % distArr.length
      const dist = distArr[distIdx]
      const poVol = monthlyVol / poCount

      const lines = []

      // OBAT: 70% budget
      const obatLineCount = kelas === 'A' ? randInt(25, 40) : kelas === 'B' ? randInt(18, 30) : randInt(12, 20)
      const obatBudget = poVol * 0.70
      for (const item of pickN(obatPool, obatLineCount)) {
        const price = Math.round(Number(item.fix_price) * rand(1.06, 1.15))
        const qty = Math.max(5, Math.round(obatBudget / obatLineCount / price * rand(0.5, 1.5)))
        lines.push({ kfa_code: item.kfa_code, item_name: item.name, catalog_type: 'obat', uom: item.uom || 'tablet', ordered_qty: qty, received_qty: qty, unit_price: price, line_total: qty * price })
      }

      // BMHP: 25% budget
      const bmhpLineCount = kelas === 'A' ? randInt(10, 18) : kelas === 'B' ? randInt(8, 12) : randInt(5, 10)
      const bmhpBudget = poVol * 0.25
      for (const item of pickN(bmhpPool, bmhpLineCount)) {
        const price = Math.round(Number(item.fix_price) * rand(1.05, 1.12))
        const qty = Math.max(20, Math.round(bmhpBudget / bmhpLineCount / price * rand(0.6, 1.4)))
        lines.push({ kfa_code: item.kfa_code, item_name: item.name, catalog_type: 'bmhp', uom: item.uom || 'box', ordered_qty: qty, received_qty: qty, unit_price: price, line_total: qty * price })
      }

      // ALKES: 5% budget
      const alkesLineCount = randInt(2, 5)
      const alkesBudget = poVol * 0.05
      for (const item of pickN(alkesPool, alkesLineCount)) {
        const price = Math.round(Number(item.fix_price) * rand(1.08, 1.22))
        const qty = Math.max(1, Math.round(alkesBudget / alkesLineCount / price * rand(0.5, 1.5)))
        lines.push({ kfa_code: item.kfa_code, item_name: item.name, catalog_type: 'alkes', uom: item.uom || 'unit', ordered_qty: qty, received_qty: qty, unit_price: price, line_total: qty * price })
      }

      const subtotal = lines.reduce((s, l) => s + l.line_total, 0)
      const tax = Math.round(subtotal * 0.11)
      const total = subtotal + tax
      const isSCF = Math.random() < 0.80

      // PO date: Desember 2025 (1-20, sisakan ruang untuk H+1 invoice)
      const poDay = randInt(1, 20)
      const poDate = `2025-12-${String(poDay).padStart(2, '0')}`
      const poNumber = `KSM-PO-2025-${String(poSeq++).padStart(5, '0')}`
      const expectedDelivery = new Date(new Date(poDate).getTime() + randInt(3,7)*86400000).toISOString().slice(0,10)

      const { data: po, error: poErr } = await sb.from('ksm_purchase_orders').insert({
        ksm_tenant_id: KSM_ID, supplier_tenant_id: dist.id, rs_tenant_id: rs.id,
        po_number: poNumber, po_date: poDate,
        expected_delivery: expectedDelivery,
        status: 'fully_received',
        payment_terms: isSCF ? 'net_30' : 'net_45',
        subtotal, tax_amount: tax, total_amount: total,
        submitted_at: new Date(poDate).toISOString(),
        metadata: { rs_name: rs.name, rs_address: rs.metadata?.city ?? '', supplier_name: dist.name, payment_method: isSCF ? 'scf' : 'termin' }
      }).select('id').single()

      if (poErr) { console.log(`  ✗ PO: ${poErr.message}`); continue }

      await sb.from('ksm_po_lines').insert(lines.map(l => ({ ...l, po_id: po.id })))
      totalPOs++; totalValue += total

      // ── Invoice H+1 (Desember 2025) ──────────────────────────────────────
      const invDate = new Date(new Date(poDate).getTime() + 1*86400000)
      const invDateStr = invDate.toISOString().slice(0,10)
      const invDueDate = new Date(invDate.getTime() + 30*86400000).toISOString().slice(0,10)
      const invNumber = `INV-KSM-2025-${String(invSeq++).padStart(5, '0')}`

      // Desember 2025 = sudah lewat, kebanyakan sudah paid
      const r = Math.random()
      let invStatus, invPaid, bpjsAmt, bpjsDate, shortfall = 0, shortfallBank = false

      if (r < 0.60) {
        // 60% paid penuh
        invStatus = 'paid'; invPaid = total
        bpjsAmt = total
        bpjsDate = new Date(invDate.getTime() + randInt(20,30)*86400000).toISOString().slice(0,10)
      } else if (r < 0.85) {
        // 25% partially paid — BPJS kurang, ada shortfall
        bpjsAmt = Math.round(total * rand(0.70, 0.88))
        invPaid = bpjsAmt; shortfall = total - bpjsAmt; shortfallBank = true
        invStatus = 'partially_paid'
        bpjsDate = new Date(invDate.getTime() + randInt(20,30)*86400000).toISOString().slice(0,10)
      } else {
        // 15% masih payment_pending (overdue)
        invStatus = 'overdue'; invPaid = 0; bpjsAmt = null; bpjsDate = null
      }

      const { error: invErr } = await sb.from('ksm_invoices').insert({
        ksm_tenant_id: KSM_ID, rs_tenant_id: rs.id, po_id: po.id,
        invoice_number: invNumber,
        invoice_date: invDateStr,
        due_date: invDueDate,
        subtotal, tax_amount: tax, total_amount: total,
        status: invStatus, paid_amount: invPaid,
        contract_payment_days: 30,
        bpjs_amount: bpjsAmt, bpjs_received_date: bpjsDate,
        shortfall_amount: shortfall, shortfall_covered_by_bank: shortfallBank,
        shortfall_facility_id: shortfallBank && scfFacility ? scfFacility.id : null,
        reviewed_at: new Date(invDate.getTime() + 86400000).toISOString(),
        sent_to_rs_at: new Date(invDate.getTime() + 2*86400000).toISOString(),
        metadata: {
          po_number: poNumber, rs_name: rs.name,
          supplier_name: dist.name, auto_generated: true,
          period: 'dec2025'
        }
      })

      if (invErr) { console.log(`  ✗ Invoice: ${invErr.message}`); continue }
      totalInvs++

      // ── AR (Bank→Distributor) untuk SCF POs ───────────────────────────────
      if (isSCF) {
        const disbDate = new Date(new Date(poDate).getTime() + 2*86400000)
        const arDueDate = new Date(disbDate.getTime() + 30*86400000)
        const disbAmt = Math.round(subtotal * 0.88)
        const interest = Math.round(disbAmt * 0.11 / 12)
        const totalPayable = disbAmt + interest

        // Desember 2025 = AR sudah paid (sudah ~6 bulan lalu)
        const arPaid = invStatus === 'paid' ? totalPayable : Math.round(totalPayable * rand(0.7, 0.9))
        const arStatus = arPaid >= totalPayable ? 'paid' : 'disbursed'

        await sb.from('ar_accounts').insert({
          bank_tenant_id: BANK_ID, ksm_tenant_id: KSM_ID,
          ar_number: `AR-2025-${poNumber.slice(-5)}`, po_number: poNumber,
          invoice_ref: invNumber,
          invoice_amount: total,
          disbursed_amount: disbAmt,
          interest_amount: interest,
          total_payable: totalPayable,
          paid_amount: arPaid,
          invoice_date: disbDate.toISOString().slice(0,10),
          disbursement_date: disbDate.toISOString().slice(0,10),
          due_date: arDueDate.toISOString().slice(0,10),
          paid_date: arStatus === 'paid' ? arDueDate.toISOString().slice(0,10) : null,
          status: arStatus,
        })
      }
    }

    process.stdout.write(`  ✅ ${rs.name.slice(0,30)}: ${poCount} PO\n`)
  }

  console.log('\n' + '='.repeat(60))
  console.log('🎉 SEED DESEMBER 2025 SELESAI')
  console.log(`   ${rsArr.length} RS · ${totalPOs} PO · ${totalInvs} Invoice`)
  console.log(`   Total: Rp ${(totalValue/1e9).toFixed(1)} Miliar`)
  console.log(`   Laporan Januari 2026 sekarang akan menampilkan data ini.`)
  console.log('='.repeat(60))
}

seed().catch(e => { console.error('Fatal:', e.message); process.exit(1) })

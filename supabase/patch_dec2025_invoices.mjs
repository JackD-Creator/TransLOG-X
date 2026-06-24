// Buat invoice untuk Dec 2025 POs yang sudah ada (belum punya invoice)
import { createClient } from '@supabase/supabase-js'

const sb = createClient(
  'https://eccermneumcskamtitqh.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjEzMTQ3NSwiZXhwIjoyMDk3NzA3NDc1fQ.ohQ1dVpjmYPSqoASUvRjtsLSuaAts3rhzkOQR4FdBQU',
  { auth: { autoRefreshToken: false, persistSession: false } }
)
const KSM_ID  = 'de0a6815-7098-45ce-b682-1c16def8e154'
const BANK_ID = '4aa64caa-a1c3-4569-93dd-07487cbca252'

function rand(a,b){return a+Math.random()*(b-a)}
function randInt(a,b){return Math.floor(rand(a,b+1))}

async function run() {
  // Load Dec 2025 POs
  const { data: pos } = await sb.from('ksm_purchase_orders')
    .select('id,po_number,po_date,subtotal,tax_amount,total_amount,rs_tenant_id,supplier_tenant_id,metadata')
    .eq('ksm_tenant_id', KSM_ID).gte('po_date','2025-12-01').lte('po_date','2025-12-31')
    .eq('status','fully_received')
  console.log(`Found ${pos?.length} Dec 2025 POs\n`)

  // Load SCF facility
  const { data: scfData } = await sb.from('scf_facilities')
    .select('id').eq('borrower_tenant_id',KSM_ID).eq('status','approved').limit(1)
  const scfId = scfData?.[0]?.id ?? null

  // Get invoice sequence start
  const { data: lastInv } = await sb.from('ksm_invoices')
    .select('invoice_number').ilike('invoice_number','INV-KSM-2025-%')
    .order('invoice_number',{ascending:false}).limit(1)
  let seq = 100
  if (lastInv?.[0]) {
    const n = parseInt(lastInv[0].invoice_number.replace(/\D/g,'').slice(-5))
    if (n >= seq) seq = n + 1
  }

  let ok = 0
  for (const po of (pos ?? [])) {
    const total = Number(po.total_amount)
    const subtotal = Number(po.subtotal)
    const tax = Number(po.tax_amount)
    const invDate = new Date(new Date(po.po_date).getTime() + 86400000)
    const invDateStr = invDate.toISOString().slice(0,10)
    const invDue = new Date(invDate.getTime() + 30*86400000).toISOString().slice(0,10)
    const invNumber = `INV-KSM-2025-${String(seq++).padStart(5,'0')}`
    const isSCF = po.metadata?.payment_method === 'scf'

    const r = Math.random()
    let status, paid, bpjsAmt, bpjsDate, shortfall = 0, sfBank = false
    if (r < 0.65) {
      status='paid'; paid=total; bpjsAmt=total
      bpjsDate=new Date(invDate.getTime()+randInt(20,30)*86400000).toISOString().slice(0,10)
    } else if (r < 0.88) {
      bpjsAmt=Math.round(total*rand(0.70,0.88)); paid=bpjsAmt
      shortfall=total-bpjsAmt; sfBank=true; status='partially_paid'
      bpjsDate=new Date(invDate.getTime()+randInt(20,30)*86400000).toISOString().slice(0,10)
    } else {
      status='overdue'; paid=0; bpjsAmt=null; bpjsDate=null
    }

    const { error } = await sb.from('ksm_invoices').insert({
      ksm_tenant_id: KSM_ID, rs_tenant_id: po.rs_tenant_id, po_id: po.id,
      invoice_number: invNumber, invoice_date: invDateStr, due_date: invDue,
      subtotal, tax_amount: tax, total_amount: total,
      status, paid_amount: paid, contract_payment_days: 30,
      bpjs_amount: bpjsAmt, bpjs_received_date: bpjsDate,
      shortfall_amount: shortfall, shortfall_covered_by_bank: sfBank,
      shortfall_facility_id: sfBank && scfId ? scfId : null,
      reviewed_at: new Date(invDate.getTime()+86400000).toISOString(),
      sent_to_rs_at: new Date(invDate.getTime()+2*86400000).toISOString(),
      metadata: { po_number: po.po_number, rs_name: po.metadata?.rs_name,
        supplier_name: po.metadata?.supplier_name, auto_generated: true }
    })
    if (error) console.log(`  ✗ ${invNumber}: ${error.message}`)
    else { ok++; if (isSCF) {
      const disbAmt = Math.round(subtotal*0.88)
      const interest = Math.round(disbAmt*0.11/12)
      const totalPay = disbAmt+interest
      const arPaid = status==='paid' ? totalPay : Math.round(totalPay*rand(0.7,0.9))
      const disbDate = new Date(new Date(po.po_date).getTime()+2*86400000)
      await sb.from('ar_accounts').insert({
        bank_tenant_id:BANK_ID, ksm_tenant_id:KSM_ID,
        ar_number:`AR-2025-${po.po_number.slice(-5)}`, po_number:po.po_number, invoice_ref:invNumber,
        invoice_amount:total, disbursed_amount:disbAmt, interest_amount:interest,
        total_payable:totalPay, paid_amount:arPaid,
        invoice_date:disbDate.toISOString().slice(0,10), disbursement_date:disbDate.toISOString().slice(0,10),
        due_date:new Date(disbDate.getTime()+30*86400000).toISOString().slice(0,10),
        paid_date:arPaid>=totalPay?new Date(disbDate.getTime()+30*86400000).toISOString().slice(0,10):null,
        status:arPaid>=totalPay?'paid':'disbursed'
      })
    }}
  }
  console.log(`✅ ${ok}/${pos?.length} invoice Desember 2025 dibuat`)
}
run().catch(e=>{console.error(e.message);process.exit(1)})

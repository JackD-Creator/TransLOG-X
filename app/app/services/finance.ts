import type { SupabaseClient } from '@supabase/supabase-js'
import type { ARAccount, SCFFacility } from '~/types/models'

const AR_SELECT = 'id,ar_number,po_number,invoice_ref,invoice_amount,disbursed_amount,interest_amount,total_payable,paid_amount,outstanding_amount,invoice_date,disbursement_date,due_date,paid_date,status'

export async function fetchARList(sb: SupabaseClient, ksmTenantId: string, statusFilter?: string) {
  let query = sb
    .from('ar_accounts')
    .select(AR_SELECT)
    .eq('ksm_tenant_id', ksmTenantId)
    .order('due_date', { ascending: true })
    .limit(100)
  if (statusFilter && statusFilter !== 'all') query = query.eq('status', statusFilter)
  const { data, error } = await query
  if (error) throw error
  return (data ?? []) as ARAccount[]
}

export async function fetchSCFFacilities(sb: SupabaseClient, ksmTenantId: string) {
  const { data, error } = await sb
    .from('scf_facilities')
    .select('id,facility_number,financing_type,facility_limit,outstanding,available_limit,interest_rate_pa,tenor_days,payment_terms,status,facility_start,facility_end,standing_instruction_active')
    .eq('borrower_tenant_id', ksmTenantId)
    .order('facility_start', { ascending: false })
  if (error) throw error
  return (data ?? []) as SCFFacility[]
}

export async function fetchPOsForPL(sb: SupabaseClient, ksmTenantId: string, startDate: string, endDate: string) {
  const { data, error } = await sb
    .from('ksm_purchase_orders')
    .select('total_amount,subtotal,tax_amount,status,po_date')
    .eq('ksm_tenant_id', ksmTenantId)
    .eq('status', 'fully_received')
    .gte('po_date', startDate)
    .lte('po_date', endDate)
  if (error) throw error
  return data ?? []
}

export async function fetchARForPeriod(sb: SupabaseClient, ksmTenantId: string, startDate: string, endDate: string) {
  const { data, error } = await sb
    .from('ar_accounts')
    .select('interest_amount,invoice_amount,status')
    .eq('ksm_tenant_id', ksmTenantId)
    .gte('invoice_date', startDate)
    .lte('invoice_date', endDate)
  if (error) throw error
  return data ?? []
}

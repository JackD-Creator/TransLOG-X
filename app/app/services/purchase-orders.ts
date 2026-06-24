import type { SupabaseClient } from '@supabase/supabase-js'
import type { PurchaseOrder } from '~/types/models'

const PO_SELECT = '*, ksm_po_lines(*)'
const PO_LIST_SELECT = 'id,po_number,po_date,expected_delivery,status,total_amount,payment_terms,metadata,ksm_po_lines(id,item_name,kfa_code,uom,ordered_qty,received_qty)'

export async function fetchPO(sb: SupabaseClient, poId: string) {
  const { data, error } = await sb
    .from('ksm_purchase_orders')
    .select(PO_SELECT)
    .eq('id', poId)
    .single()
  if (error) throw error
  return data as PurchaseOrder
}

export async function fetchPOList(sb: SupabaseClient, ksmTenantId: string, statusFilter?: string[]) {
  let query = sb
    .from('ksm_purchase_orders')
    .select(PO_LIST_SELECT)
    .eq('ksm_tenant_id', ksmTenantId)
    .order('po_date', { ascending: false })
    .limit(100)
  if (statusFilter?.length) query = query.in('status', statusFilter)
  const { data, error } = await query
  if (error) throw error
  return (data ?? []) as PurchaseOrder[]
}

export async function updatePOStatus(sb: SupabaseClient, poId: string, status: string) {
  const { error } = await sb
    .from('ksm_purchase_orders')
    .update({ status })
    .eq('id', poId)
  if (error) throw error
}

export async function supplierConfirmPO(sb: SupabaseClient, poId: string, confirmation: Record<string, unknown>) {
  const { data, error } = await sb.rpc('supplier_confirm_po', {
    p_po_id: poId,
    p_confirmation: confirmation,
  })
  if (error) throw error
  return data
}

export async function ksmRequestCorrection(sb: SupabaseClient, poId: string, reason: string) {
  const { data, error } = await sb.rpc('ksm_request_po_correction', {
    p_po_id: poId,
    p_reason: reason,
  })
  if (error) throw error
  return data
}

export async function ksmApprovePO(sb: SupabaseClient, poId: string) {
  const { data, error } = await sb.rpc('ksm_approve_po', { p_po_id: poId })
  if (error) throw error
  return data
}

export async function rsConfirmReceipt(sb: SupabaseClient, poId: string, items: { line_id: string; received_qty: number }[]) {
  const { data, error } = await sb.rpc('rs_confirm_receipt', {
    p_po_id: poId,
    p_received_items: items,
  })
  if (error) throw error
  return data
}

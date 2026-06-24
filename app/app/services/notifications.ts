import type { SupabaseClient } from '@supabase/supabase-js'
import type { Notification } from '~/types/models'

const NOTIF_SELECT = 'id,notif_number,notif_date,rs_tenant_id,status,notes,metadata,acknowledged_at,hospital_notification_lines(id,kfa_code,item_name,catalog_type,uom,current_stock,min_stock,requested_qty,approved_qty,notes)'

export async function fetchNotifications(sb: SupabaseClient, ksmTenantId: string) {
  const { data, error } = await sb
    .from('hospital_notifications')
    .select(NOTIF_SELECT)
    .eq('ksm_tenant_id', ksmTenantId)
    .order('notif_date', { ascending: false })
    .limit(100)
  if (error) throw error
  return (data ?? []) as Notification[]
}

export async function reviewAndCheckSupplier(sb: SupabaseClient, notifId: string) {
  const { data, error } = await sb.rpc('notif_review_and_check_supplier', { p_notif_id: notifId })
  if (error) throw error
  return data
}

export async function supplierConfirm(sb: SupabaseClient, notifId: string) {
  const { data, error } = await sb.rpc('notif_supplier_confirm', { p_notif_id: notifId })
  if (error) throw error
  return data
}

export async function createPOFromNotification(sb: SupabaseClient, notifId: string, supplierTenantId?: string) {
  const params: Record<string, string> = { p_notif_id: notifId }
  if (supplierTenantId) params.p_supplier_tenant_id = supplierTenantId
  const { data, error } = await sb.rpc('create_po_from_notification', params)
  if (error) throw error
  return data
}

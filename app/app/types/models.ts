export interface Notification {
  id: string
  notif_number: string
  notif_date: string
  rs_tenant_id: string
  ksm_tenant_id: string
  status: 'pending' | 'acknowledged' | 'po_created' | 'completed' | 'cancelled'
  notes: string | null
  metadata: NotifMetadata
  acknowledged_at: string | null
  hospital_notification_lines?: NotificationLine[]
  created_at: string
}

export interface NotifMetadata {
  rs_name?: string
  rs_address?: string
  urgency?: 'normal' | 'high' | 'critical'
  supplier_check?: 'checking' | 'confirmed'
  supplier_confirmed_at?: string
  supplier_availability?: SupplierAvailItem[]
  po_number?: string
  po_id?: string
}

export interface SupplierAvailItem {
  kfa_code: string
  item_name: string
  requested_qty: number
  available: boolean
  stock: number
  sell_price: number
  lead_time: number
  distributor: string
}

export interface NotificationLine {
  id: string
  notification_id: string
  kfa_code: string
  item_name: string
  catalog_type: 'obat' | 'alkes' | 'bmhp'
  uom: string
  current_stock: number
  min_stock: number
  requested_qty: number
  approved_qty: number | null
  notes: string | null
}

export interface PurchaseOrder {
  id: string
  ksm_tenant_id: string
  supplier_tenant_id: string
  rs_tenant_id: string | null
  notification_id: string | null
  po_number: string
  po_date: string
  expected_delivery: string | null
  status: 'draft' | 'submitted' | 'approved' | 'sent_to_supplier' | 'partially_received' | 'fully_received' | 'cancelled'
  payment_terms: string
  subtotal: number
  tax_amount: number
  total_amount: number
  submitted_at: string | null
  approved_at: string | null
  sent_at: string | null
  notes: string | null
  metadata: POMetadata
  ksm_po_lines?: POLine[]
  created_at: string
}

export interface POMetadata {
  rs_name?: string
  rs_address?: string
  supplier_name?: string
  tracking_number?: string
  courier?: string
  auto_from_notif?: string
  needs_ksm_review?: boolean
  correction_requested?: boolean
  correction_reason?: string
  supplier_confirmation?: Record<string, unknown>
  rs_delivery_info?: Record<string, unknown>
}

export interface POLine {
  id: string
  po_id: string
  kfa_code: string
  item_name: string
  catalog_type: 'obat' | 'alkes' | 'bmhp'
  uom: string
  ordered_qty: number
  received_qty: number
  unit_price: number
  line_total: number
  notes: string | null
}

export interface ARAccount {
  id: string
  ar_number: string
  po_number: string | null
  invoice_ref: string | null
  invoice_amount: number
  disbursed_amount: number
  interest_amount: number
  total_payable: number
  paid_amount: number
  outstanding_amount: number | null
  invoice_date: string | null
  disbursement_date: string | null
  due_date: string
  paid_date: string | null
  status: 'pending' | 'disbursed' | 'partially_paid' | 'paid' | 'overdue' | 'defaulted'
  ksm_tenant_id: string
  bank_tenant_id: string
}

export interface SCFFacility {
  id: string
  facility_number: string
  financing_type: string
  facility_limit: number
  outstanding: number
  available_limit: number
  interest_rate_pa: number
  tenor_days: number
  payment_terms: string
  status: string
  facility_start: string
  facility_end: string
  standing_instruction_active: boolean
  borrower_tenant_id: string
  bank_tenant_id: string
}

export interface KFADrug {
  kfa_code: string
  name: string
  nama_dagang: string | null
  dosage_form: string | null
  strength: string | null
  manufacturer: string | null
  distributor: string | null
  fix_price: number | null
  het_price: number | null
  is_fornas: boolean | null
  uom: string
}

export interface SupplierCatalogItem {
  kfa_code: string
  name: string
  sell_price: number
  stock_available: number
  lead_time_days: number
  metadata: { distributor_name?: string; distributor_id?: string }
}

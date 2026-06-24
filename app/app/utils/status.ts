export const PO_STATUS = {
  draft:              { label: 'Draft',              color: 'bg-[#f0f0f0] text-[#999]' },
  submitted:          { label: 'Diajukan ke Dist.',  color: 'bg-blue-100 text-blue-700' },
  approved:           { label: 'Dist. Konfirmasi',   color: 'bg-purple-100 text-purple-700' },
  sent_to_supplier:   { label: 'Dikirim ke RS',      color: 'bg-amber-100 text-amber-700' },
  partially_received: { label: 'RS Terima Sebagian', color: 'bg-orange-100 text-orange-700' },
  fully_received:     { label: 'RS Terima Lengkap',  color: 'bg-emerald-100 text-emerald-700' },
  cancelled:          { label: 'Dibatalkan',         color: 'bg-red-100 text-red-700' },
} as const

export const AR_STATUS = {
  pending:        { label: 'Pending',           color: 'bg-[#f0f0f0] text-[#999]' },
  disbursed:      { label: 'Cair ke Dist.',     color: 'bg-blue-100 text-blue-700' },
  partially_paid: { label: 'Dibayar Sebagian',  color: 'bg-amber-100 text-amber-700' },
  paid:           { label: 'Lunas',             color: 'bg-emerald-100 text-emerald-700' },
  overdue:        { label: 'Jatuh Tempo',       color: 'bg-red-100 text-red-700' },
  defaulted:      { label: 'Default',           color: 'bg-red-200 text-red-800' },
} as const

export const NOTIF_STATUS = {
  pending:       { label: 'Menunggu Review',  color: 'bg-amber-100 text-amber-700',    step: 0 },
  acknowledged:  { label: 'Sedang Proses',    color: 'bg-blue-100 text-blue-700',      step: 1 },
  po_created:    { label: 'PO Dibuat',        color: 'bg-purple-100 text-purple-700',  step: 2 },
  completed:     { label: 'Selesai',          color: 'bg-emerald-100 text-emerald-700', step: 3 },
  cancelled:     { label: 'Dibatalkan',       color: 'bg-[#f0f0f0] text-[#999]',      step: -1 },
} as const

export type POStatus = keyof typeof PO_STATUS
export type ARStatus = keyof typeof AR_STATUS
export type NotifStatus = keyof typeof NOTIF_STATUS

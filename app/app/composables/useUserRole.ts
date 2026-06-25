// Deteksi role portal user dari app_metadata JWT (tidak perlu DB query)
// Portal groups: rumah_sakit | mitra_ksm | distributor | bank

export type PortalType = 'rumah_sakit' | 'mitra_ksm' | 'distributor' | 'bank' | null

export interface UserRoleState {
  portalType: PortalType
  tenantType: string | null
  tenantName: string | null
  tenantId: string | null
  loading: boolean
}

const RS_TYPES = ['rs_pemerintah', 'rs_swasta', 'rs_tni_polri', 'klinik', 'puskesmas']
const DIST_TYPES = ['pbf', 'distributor', 'supplier_lain']
const BANK_TYPES = ['bank', 'fintech']

function toPortalType(tenantType: string | null): PortalType {
  if (!tenantType) return null
  if (RS_TYPES.includes(tenantType)) return 'rumah_sakit'
  if (tenantType === 'mitra_ksm') return 'mitra_ksm'
  if (DIST_TYPES.includes(tenantType)) return 'distributor'
  if (BANK_TYPES.includes(tenantType)) return 'bank'
  return 'rumah_sakit'
}

export function useUserRole() {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  const state = useState<UserRoleState>('user-role', () => ({
    portalType: null,
    tenantType: null,
    tenantName: null,
    tenantId: null,
    loading: false,
  }))

  async function loadRole() {
    if (!user.value) return

    state.value.loading = true
    try {
      // Force refresh token to get latest app_metadata from server
      await supabase.auth.refreshSession()

      // Read tenant info from app_metadata (set server-side, no RLS issue)
      const { data: { user: freshUser } } = await supabase.auth.getUser()
      const meta = (freshUser as any)?.app_metadata ?? (user.value as any).app_metadata ?? {}
      let tenantType: string | null = meta.tenant_type ?? null
      let tenantName: string | null = meta.tenant_name ?? null
      let tenantId: string | null   = meta.tenant_id   ?? null

      // Fallback: query DB if app_metadata not populated yet
      if (!tenantType) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('tenant_id, tenants(type, name)')
          .eq('id', user.value.id)
          .single()
        if (profile) {
          const tenant = (profile.tenants as any)
          tenantId   = profile.tenant_id
          tenantType = tenant?.type ?? null
          tenantName = tenant?.name ?? null
        }
      }

      state.value.tenantId   = tenantId
      state.value.tenantType = tenantType
      state.value.tenantName = tenantName
      state.value.portalType = toPortalType(tenantType)
    } finally {
      state.value.loading = false
    }
  }

  watch(user, (u) => {
    if (u) {
      if (!state.value.tenantId) loadRole()
    } else {
      state.value = { portalType: null, tenantType: null, tenantName: null, tenantId: null, loading: false }
    }
  }, { immediate: true })

  return {
    portalType:    computed(() => state.value.portalType),
    tenantType:    computed(() => state.value.tenantType),
    tenantName:    computed(() => state.value.tenantName),
    tenantId:      computed(() => state.value.tenantId),
    isRS:          computed(() => state.value.portalType === 'rumah_sakit'),
    isKSM:         computed(() => state.value.portalType === 'mitra_ksm'),
    isDistributor: computed(() => state.value.portalType === 'distributor'),
    isBank:        computed(() => state.value.portalType === 'bank'),
    loading:       computed(() => state.value.loading),
    loadRole,
  }
}

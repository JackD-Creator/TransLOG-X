<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()
const user = useSupabaseUser()
const saving = ref(false)
const saved = ref(false)

const profile = ref({
  full_name: '',
  role: '',
  phone: '',
  department: '',
})

const tenant = ref({
  name: '',
  code: '',
  type: '',
  address: '',
  npwp: '',
})

async function fetchProfile() {
  if (!user.value) return

  const { data: p } = await supabase
    .from('profiles')
    .select('full_name, role, phone, department')
    .eq('id', user.value.id)
    .single()
  if (p) Object.assign(profile.value, p)

  const { data: t } = await supabase
    .from('tenants')
    .select('name, code, tenant_type, address, npwp')
    .single()
  if (t) {
    tenant.value.name = t.name
    tenant.value.code = t.code
    tenant.value.type = t.tenant_type
    tenant.value.address = t.address ?? ''
    tenant.value.npwp = t.npwp ?? ''
  }
}

async function saveProfile() {
  if (!user.value) return
  saving.value = true
  saved.value = false
  await supabase
    .from('profiles')
    .update({
      full_name: profile.value.full_name,
      phone: profile.value.phone,
      department: profile.value.department,
    })
    .eq('id', user.value.id)
  saving.value = false
  saved.value = true
  setTimeout(() => { saved.value = false }, 2000)
}

onMounted(fetchProfile)

const typeLabel: Record<string, string> = {
  hospital: 'Rumah Sakit',
  distributor: 'Distributor PBF',
  supplier: 'Supplier',
  fintech: 'Fintech / Bank',
}
</script>

<template>
  <div class="space-y-5 max-w-3xl">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Pengaturan</h1>
      <p class="text-sm text-[#999] mt-0.5">Profil pengguna & informasi tenant</p>
    </div>

    <form class="space-y-5" @submit.prevent="saveProfile">

      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 space-y-4">
        <h2 class="text-sm font-semibold text-[#666]">Profil Pengguna</h2>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Nama Lengkap</label>
            <input v-model="profile.full_name" type="text" class="inp">
          </div>
          <div>
            <label class="lbl">Email</label>
            <input :value="user?.email ?? ''" type="email" class="inp opacity-60" disabled>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Role</label>
            <input :value="profile.role" type="text" class="inp opacity-60" disabled>
          </div>
          <div>
            <label class="lbl">Departemen</label>
            <input v-model="profile.department" type="text" placeholder="Farmasi, IGD, dll." class="inp">
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Telepon</label>
            <input v-model="profile.phone" type="tel" placeholder="08xxxxxxxxxx" class="inp">
          </div>
        </div>
      </div>

      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 space-y-4">
        <h2 class="text-sm font-semibold text-[#666]">Informasi Tenant</h2>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Nama Organisasi</label>
            <input :value="tenant.name" type="text" class="inp opacity-60" disabled>
          </div>
          <div>
            <label class="lbl">Kode Tenant</label>
            <input :value="tenant.code" type="text" class="inp opacity-60" disabled>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Tipe</label>
            <input :value="typeLabel[tenant.type] ?? tenant.type" type="text" class="inp opacity-60" disabled>
          </div>
          <div>
            <label class="lbl">NPWP</label>
            <input :value="tenant.npwp" type="text" class="inp opacity-60" disabled>
          </div>
        </div>

        <div>
          <label class="lbl">Alamat</label>
          <input :value="tenant.address" type="text" class="inp opacity-60" disabled>
        </div>
      </div>

      <div class="flex items-center gap-3 justify-end">
        <span v-if="saved" class="text-sm text-emerald-600 font-medium">Tersimpan!</span>
        <UButton type="submit" color="primary" :loading="saving" icon="i-lucide-save">
          Simpan Profil
        </UButton>
      </div>

    </form>
  </div>
</template>

<style scoped>
.lbl {
  display: block; font-size: 0.72rem; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.06em;
  color: #666; margin-bottom: 6px;
}
.inp {
  width: 100%; padding: 9px 12px;
  border: 1.5px solid #e5e5e5; border-radius: 8px;
  background: #f0f0f0; color: #1a1a1a;
  font-size: 0.875rem; outline: none;
  transition: border-color 0.15s; font-family: inherit;
}
.inp:focus { border-color: #6b1525; box-shadow: 0 0 0 3px rgba(107,21,37,0.1); }
</style>

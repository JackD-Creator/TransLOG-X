<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Katalog Item KSM' })

const supabase = useSupabaseClient()

const loading = ref(true)
const items = ref<any[]>([])
const search = ref('')

const filtered = computed(() =>
  search.value.trim()
    ? items.value.filter(i => i.name.toLowerCase().includes(search.value.toLowerCase()) || i.kfa_code.includes(search.value))
    : items.value
)

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ksm_catalog_items')
    .select('*')
    .order('name', { ascending: true })
    .limit(200)
  items.value = data ?? []
  loading.value = false
}

const typeColor: Record<string, string> = {
  obat:  'bg-blue-100 text-blue-700',
  alkes: 'bg-purple-100 text-purple-700',
  bmhp:  'bg-amber-100 text-amber-700',
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Katalog Item KSM</h1>
        <p class="text-sm text-[#999] mt-0.5">Daftar item yang dikelola oleh KSM untuk RS mitra</p>
      </div>
      <div class="flex items-center gap-3">
        <div class="flex items-center gap-2 px-4 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0]">
          <UIcon name="i-lucide-search" class="text-sm text-[#999]"/>
          <input v-model="search" type="text" placeholder="Cari nama atau kode KFA..."
            class="bg-transparent text-xs text-[#1a1a1a] outline-none placeholder:text-[#999] w-48">
        </div>
        <span class="text-xs text-[#999]">{{ filtered.length }} item</span>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="filtered.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-layers" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">{{ search ? 'Tidak ada item cocok' : 'Katalog masih kosong' }}</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Kode KFA</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Nama Item</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tipe</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Satuan</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">FORNAS</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="item in filtered" :key="item.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-2.5 font-mono text-[#666]">{{ item.kfa_code }}</td>
            <td class="px-4 py-2.5">
              <p class="font-medium text-[#1a1a1a]">{{ item.name }}</p>
              <p v-if="item.generic_name" class="text-[#999]">{{ item.generic_name }}</p>
            </td>
            <td class="px-4 py-2.5">
              <span :class="['px-2 py-0.5 rounded-full font-medium', typeColor[item.catalog_type] ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ item.catalog_type.toUpperCase() }}
              </span>
            </td>
            <td class="px-4 py-2.5 text-[#666]">{{ item.uom }}</td>
            <td class="px-4 py-2.5">
              <UIcon v-if="item.is_fornas" name="i-lucide-check-circle" class="text-emerald-600"/>
              <span v-else class="text-[#ccc]">—</span>
            </td>
            <td class="px-4 py-2.5">
              <span :class="['px-2 py-0.5 rounded-full font-medium text-[10px]', item.is_active ? 'bg-emerald-100 text-emerald-700' : 'bg-[#f0f0f0] text-[#999]']">
                {{ item.is_active ? 'Aktif' : 'Nonaktif' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

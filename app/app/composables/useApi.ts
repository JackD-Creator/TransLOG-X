export function useApi() {
  const supabase = useSupabaseClient()

  async function getToken(): Promise<string> {
    const { data } = await supabase.auth.getSession()
    return data.session?.access_token ?? ''
  }

  async function apiPost<T = any>(path: string, body: Record<string, any>): Promise<T> {
    const token = await getToken()
    return $fetch<T>(path, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body,
    })
  }

  async function apiGet<T = any>(path: string): Promise<T> {
    const token = await getToken()
    return $fetch<T>(path, {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    })
  }

  return { apiPost, apiGet, getToken }
}

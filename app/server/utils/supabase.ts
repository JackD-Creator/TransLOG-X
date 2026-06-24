import { createClient } from '@supabase/supabase-js'
import type { H3Event } from 'h3'

export function useServerSupabase() {
  const config = useRuntimeConfig()
  return createClient(
    config.public?.supabaseUrl || process.env.SUPABASE_URL || 'https://eccermneumcskamtitqh.supabase.co',
    process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '',
    { auth: { autoRefreshToken: false, persistSession: false } }
  )
}

export async function requireAuth(event: H3Event) {
  const authHeader = getHeader(event, 'authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized — token required' })
  }
  const token = authHeader.slice(7)
  const sb = useServerSupabase()
  const { data: { user }, error } = await sb.auth.getUser(token)
  if (error || !user) {
    throw createError({ statusCode: 401, statusMessage: 'Invalid or expired token' })
  }
  return { user, tenantId: user.app_metadata?.tenant_id as string, tenantType: user.app_metadata?.tenant_type as string }
}

// TransLOG-X — Demo Account Seeder
// Usage: node supabase/seed_demo.mjs
// Creates: demo tenant + admin user + role assignment

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://eccermneumcskamtitqh.supabase.co';
const SERVICE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjEzMTQ3NSwiZXhwIjoyMDk3NzA3NDc1fQ.ohQ1dVpjmYPSqoASUvRjtsLSuaAts3rhzkOQR4FdBQU';

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

const DEMO = {
  email:    'demo@translogx.id',
  password: 'Demo1234!',
  tenant: {
    name:       'RS Umum Demo',
    short_name: 'RSU Demo',
    type:       'rs_swasta',
    status:     'active',
    email:      'admin@rsudemo.id',
    phone:      '+6281234567890',
    city:       'Jakarta Selatan',
    province:   'DKI Jakarta',
    kyc_status: 'verified',
    npwp:       '12.345.678.9-012.000',
    kelas_rs:   'B',
    bpjs_ppk_code: 'DEMO001'
  },
  profile: {
    full_name:   'Admin Demo',
    employee_id: 'EMP-001',
    title:       'Administrator',
    department:  'IT'
  }
};

async function seed() {
  console.log('🌱 Seeding demo account...\n');

  // 1. Create or get tenant
  let tenantId;
  const { data: existingTenant } = await supabase
    .from('tenants').select('id').eq('email', DEMO.tenant.email).single();

  if (existingTenant) {
    tenantId = existingTenant.id;
    console.log('⏭️  Tenant already exists:', tenantId);
  } else {
    const { data: tenant, error: tErr } = await supabase
      .from('tenants').insert(DEMO.tenant).select('id').single();
    if (tErr) throw new Error('Tenant: ' + tErr.message);
    tenantId = tenant.id;
    console.log('✅ Tenant created:', tenantId);
  }

  // 2. Create auth user (or get existing)
  let userId;
  const { data: existingUsers } = await supabase.auth.admin.listUsers();
  const existing = existingUsers?.users?.find(u => u.email === DEMO.email);

  if (existing) {
    userId = existing.id;
    // Update password in case it changed
    await supabase.auth.admin.updateUserById(userId, { password: DEMO.password });
    console.log('⏭️  Auth user already exists:', userId);
  } else {
    const { data: authUser, error: aErr } = await supabase.auth.admin.createUser({
      email: DEMO.email,
      password: DEMO.password,
      email_confirm: true,
      app_metadata: { tenant_id: tenantId }
    });
    if (aErr) throw new Error('Auth user: ' + aErr.message);
    userId = authUser.user.id;
    console.log('✅ Auth user created:', userId);
  }

  // 3. Update app_metadata with tenant_id (needed for RLS JWT claim)
  await supabase.auth.admin.updateUserById(userId, {
    app_metadata: { tenant_id: tenantId }
  });
  console.log('✅ JWT app_metadata set: tenant_id =', tenantId);

  // 4. Create profile
  const { error: pErr } = await supabase.from('profiles').upsert({
    id:          userId,
    tenant_id:   tenantId,
    full_name:   DEMO.profile.full_name,
    employee_id: DEMO.profile.employee_id,
    title:       DEMO.profile.title,
    department:  DEMO.profile.department,
    status:      'active'
  }, { onConflict: 'id' });
  if (pErr) throw new Error('Profile: ' + pErr.message);
  console.log('✅ Profile created/updated');

  // 5. Assign tenant_admin role
  const { data: role } = await supabase
    .from('roles').select('id').eq('name', 'tenant_admin').is('tenant_id', null).single();

  if (role) {
    const { error: rErr } = await supabase.from('user_roles').upsert({
      user_id: userId, role_id: role.id, tenant_id: tenantId
    }, { onConflict: 'user_id,role_id' });
    if (rErr) throw new Error('Role: ' + rErr.message);
    console.log('✅ Role assigned: tenant_admin');
  } else {
    console.warn('⚠️  Role tenant_admin not found — skipped');
  }

  console.log('\n🎉 Demo account ready!\n');
  console.log('   Email   :', DEMO.email);
  console.log('   Password:', DEMO.password);
  console.log('   Tenant  :', DEMO.tenant.name, '(' + tenantId + ')');
  console.log('   User ID :', userId);
}

seed().catch(err => {
  console.error('❌', err.message);
  process.exit(1);
});

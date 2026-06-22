-- =============================================================================
-- TransLOG-X  |  00_foundation.sql
-- Foundation schema: extensions, enums, tenants, profiles, RBAC, audit_log
-- Database: Supabase Pro (PostgreSQL 15+)
-- =============================================================================

-- =============================================================================
-- EXTENSIONS
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- fuzzy text search
CREATE EXTENSION IF NOT EXISTS "unaccent";        -- Indonesian text normalization
CREATE EXTENSION IF NOT EXISTS "pgcrypto";        -- hashing utilities

-- =============================================================================
-- ENUMS
-- =============================================================================

-- Tenant / Organization
CREATE TYPE tenant_type AS ENUM (
  'rs_pemerintah', 'rs_swasta', 'rs_tni_polri',
  'klinik', 'puskesmas', 'pbf', 'distributor',
  'mitra_ksm', 'bank', 'fintech', 'supplier_lain'
);
CREATE TYPE tenant_status AS ENUM ('pending_kyc', 'active', 'suspended', 'terminated');
CREATE TYPE kelas_rs AS ENUM ('A', 'B', 'C', 'D');

-- User
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'locked');
CREATE TYPE kyc_status  AS ENUM ('not_started', 'in_progress', 'verified', 'rejected', 'expired');

-- General
CREATE TYPE approval_status AS ENUM (
  'draft', 'pending', 'approved', 'rejected', 'cancelled', 'expired'
);
CREATE TYPE priority_level AS ENUM ('low', 'medium', 'high', 'critical');

-- Product / Item
CREATE TYPE product_category AS ENUM (
  'obat', 'alkes', 'bmhp', 'reagensia',
  'makanan_minuman', 'gas_medis', 'lain_lain'
);
CREATE TYPE storage_condition AS ENUM (
  'room_temp', 'refrigerated', 'frozen',
  'controlled_substance', 'flammable', 'special'
);

-- Procurement / Order
CREATE TYPE po_status AS ENUM (
  'draft', 'submitted', 'approved', 'sent_to_supplier',
  'partially_received', 'fully_received', 'cancelled', 'closed'
);
CREATE TYPE payment_terms AS ENUM (
  'cod', 'net_7', 'net_14', 'net_30', 'net_45', 'net_60', 'net_90', 'net_120'
);

-- Financial
CREATE TYPE currency_code   AS ENUM ('IDR', 'USD');
CREATE TYPE invoice_status  AS ENUM (
  'draft', 'sent', 'partially_paid', 'paid', 'overdue', 'disputed', 'cancelled'
);
CREATE TYPE financing_type AS ENUM (
  'reverse_factoring', 'invoice_financing', 'dynamic_discounting',
  'bpjs_bridging', 'po_financing', 'inventory_financing'
);
CREATE TYPE financing_status AS ENUM (
  'draft', 'submitted', 'under_review', 'approved', 'disbursed',
  'partially_repaid', 'fully_repaid', 'defaulted', 'rejected', 'cancelled'
);
CREATE TYPE payment_method AS ENUM (
  'bank_transfer', 'virtual_account', 'snap_qris', 'snap_va',
  'debit', 'escrow', 'giro'
);

-- Warehouse / Movement
CREATE TYPE movement_type AS ENUM (
  'receive', 'issue', 'transfer', 'adjustment',
  'return_in', 'return_out', 'disposal', 'recall'
);

-- BPJS / RCM
CREATE TYPE claim_status AS ENUM (
  'draft', 'submitted', 'verified', 'processed',
  'approved', 'partially_approved', 'rejected',
  'appealed', 'paid', 'cancelled'
);

-- Notification
CREATE TYPE notification_channel  AS ENUM ('in_app', 'email', 'sms', 'whatsapp', 'push');
CREATE TYPE notification_status   AS ENUM ('pending', 'sent', 'delivered', 'failed', 'read');

-- =============================================================================
-- HELPER FUNCTION: set updated_at
-- =============================================================================
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- =============================================================================
-- HELPER FUNCTION: get current tenant_id from JWT
-- Used in all RLS policies
-- Supabase stores custom claim in auth.jwt() -> 'app_metadata' -> 'tenant_id'
-- =============================================================================
CREATE OR REPLACE FUNCTION current_tenant_id()
RETURNS UUID LANGUAGE sql STABLE AS $$
  SELECT (auth.jwt() -> 'app_metadata' ->> 'tenant_id')::UUID;
$$;

-- Returns TRUE when caller is a service-role key (no tenant restriction)
CREATE OR REPLACE FUNCTION is_service_role()
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT (auth.jwt() ->> 'role') = 'service_role';
$$;

-- =============================================================================
-- TENANTS
-- Each RS, supplier, bank, mitra KSM = 1 tenant (multi-tenant SaaS)
-- =============================================================================
CREATE TABLE tenants (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  short_name    TEXT,
  type          tenant_type NOT NULL,
  status        tenant_status NOT NULL DEFAULT 'pending_kyc',

  -- Legal identity
  npwp          TEXT,
  nib           TEXT UNIQUE,           -- Nomor Induk Berusaha (OSS)
  izin_operasional TEXT,
  akreditasi    TEXT,                  -- KARS / SNARS / ISO
  kelas_rs      kelas_rs,             -- khusus RS
  bpjs_ppk_code TEXT,                 -- kode PPK BPJS Kesehatan

  -- Contact
  email         TEXT NOT NULL,
  phone         TEXT,
  website       TEXT,
  address       TEXT,
  city          TEXT,
  province      TEXT,
  postal_code   TEXT,
  lat           NUMERIC(10, 7),
  lng           NUMERIC(10, 7),

  -- KYC
  kyc_status    kyc_status NOT NULL DEFAULT 'not_started',
  kyc_verified_at  TIMESTAMPTZ,
  kyc_verified_by  UUID,               -- references profiles.id (set after)

  -- Config & metadata
  settings      JSONB NOT NULL DEFAULT '{}',
  metadata      JSONB NOT NULL DEFAULT '{}',

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ           -- soft delete
);

CREATE INDEX idx_tenants_type    ON tenants(type);
CREATE INDEX idx_tenants_status  ON tenants(status);
CREATE INDEX idx_tenants_name    ON tenants USING gin(name gin_trgm_ops);

CREATE TRIGGER trg_tenants_updated_at
  BEFORE UPDATE ON tenants
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- PROFILES  (extends Supabase auth.users 1:1)
-- =============================================================================
CREATE TABLE profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id     UUID NOT NULL REFERENCES tenants(id),

  full_name     TEXT NOT NULL,
  employee_id   TEXT,                  -- ID karyawan internal RS
  title         TEXT,                  -- Jabatan
  department    TEXT,

  phone         TEXT,
  avatar_url    TEXT,
  status        user_status NOT NULL DEFAULT 'active',

  -- eKYC
  nik           TEXT,
  nik_verified  BOOLEAN NOT NULL DEFAULT FALSE,
  nik_verified_at TIMESTAMPTZ,

  -- Security
  mfa_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
  last_login_at TIMESTAMPTZ,
  failed_login_count INT NOT NULL DEFAULT 0,
  locked_until  TIMESTAMPTZ,

  metadata      JSONB NOT NULL DEFAULT '{}',

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_profiles_tenant  ON profiles(tenant_id);
CREATE INDEX idx_profiles_name    ON profiles USING gin(full_name gin_trgm_ops);

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- After both tables exist, add FK for kyc_verified_by
ALTER TABLE tenants
  ADD CONSTRAINT fk_tenants_kyc_verifier
  FOREIGN KEY (kyc_verified_by) REFERENCES profiles(id);

-- =============================================================================
-- RBAC: ROLES
-- System roles (tenant_id IS NULL) are global templates.
-- Tenant-specific roles have tenant_id set.
-- =============================================================================
CREATE TABLE roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID REFERENCES tenants(id) ON DELETE CASCADE,  -- NULL = system role
  name        TEXT NOT NULL,
  description TEXT,
  is_system   BOOLEAN NOT NULL DEFAULT FALSE,
  metadata    JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, name)
);

-- Seed default system roles
INSERT INTO roles (id, name, description, is_system) VALUES
  (gen_random_uuid(), 'super_admin',          'TransLOG-X platform admin',             TRUE),
  (gen_random_uuid(), 'tenant_admin',         'Tenant administrator',                  TRUE),
  (gen_random_uuid(), 'procurement_manager',  'Kelola pengadaan & PO',                 TRUE),
  (gen_random_uuid(), 'procurement_staff',    'Buat dan submit PR/RFQ',                TRUE),
  (gen_random_uuid(), 'warehouse_manager',    'Kelola gudang & distribusi',            TRUE),
  (gen_random_uuid(), 'warehouse_staff',      'Receive, pick, pack barang',            TRUE),
  (gen_random_uuid(), 'finance_manager',      'Kelola invoice, payment, financing',    TRUE),
  (gen_random_uuid(), 'finance_staff',        'Input & proses dokumen keuangan',       TRUE),
  (gen_random_uuid(), 'bpjs_officer',         'Kelola klaim BPJS & RCM',              TRUE),
  (gen_random_uuid(), 'inventory_manager',    'Kelola stok & formularium',             TRUE),
  (gen_random_uuid(), 'qms_officer',          'Kelola CAPA & audit',                   TRUE),
  (gen_random_uuid(), 'compliance_officer',   'Kelola regulasi & pelaporan',           TRUE),
  (gen_random_uuid(), 'credit_analyst',       'Analisis kredit & risiko',              TRUE),
  (gen_random_uuid(), 'driver',               'Driver delivery & ePOD',               TRUE),
  (gen_random_uuid(), 'supplier_user',        'Akses vendor portal (read-only)',       TRUE),
  (gen_random_uuid(), 'auditor',              'Read-only audit access semua modul',    TRUE),
  (gen_random_uuid(), 'viewer',               'Read-only dashboard',                   TRUE);

-- =============================================================================
-- RBAC: PERMISSIONS
-- module.resource.action pattern
-- =============================================================================
CREATE TABLE permissions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module      TEXT NOT NULL,    -- inventory, procurement, warehouse, financial, ...
  resource    TEXT NOT NULL,    -- product, purchase_order, invoice, ...
  action      TEXT NOT NULL,    -- create, read, update, delete, approve, submit, export
  description TEXT,
  UNIQUE (module, resource, action)
);

-- Core permissions (sample — expand as modules are built)
INSERT INTO permissions (module, resource, action) VALUES
  -- Inventory
  ('inventory', 'product',          'create'), ('inventory', 'product',          'read'),
  ('inventory', 'product',          'update'), ('inventory', 'product',          'delete'),
  ('inventory', 'stock',            'read'),   ('inventory', 'stock',            'adjust'),
  ('inventory', 'stock_count',      'create'), ('inventory', 'stock_count',      'approve'),
  ('inventory', 'reorder_rule',     'create'), ('inventory', 'reorder_rule',     'update'),
  -- Procurement
  ('procurement', 'purchase_request', 'create'), ('procurement', 'purchase_request', 'approve'),
  ('procurement', 'rfq',              'create'), ('procurement', 'rfq',              'send'),
  ('procurement', 'purchase_order',   'create'), ('procurement', 'purchase_order',   'approve'),
  ('procurement', 'purchase_order',   'cancel'), ('procurement', 'supplier',          'create'),
  ('procurement', 'supplier',          'approve'),
  -- Warehouse
  ('warehouse', 'grn',      'create'), ('warehouse', 'grn',      'approve'),
  ('warehouse', 'shipment', 'create'), ('warehouse', 'shipment', 'dispatch'),
  ('warehouse', 'picking',  'create'),
  -- Financial
  ('financial', 'invoice',   'create'), ('financial', 'invoice',   'approve'),
  ('financial', 'payment',   'create'), ('financial', 'payment',   'approve'),
  ('financial', 'financing', 'apply'),  ('financial', 'financing', 'approve'),
  -- BPJS
  ('rcm', 'bpjs_claim', 'create'), ('rcm', 'bpjs_claim', 'submit'),
  ('rcm', 'bpjs_claim', 'appeal'),
  -- Reports
  ('analytics', 'report', 'read'), ('analytics', 'report', 'export'),
  -- Admin
  ('admin', 'user',   'create'), ('admin', 'user',   'update'),
  ('admin', 'role',   'assign'), ('admin', 'tenant', 'update');

-- =============================================================================
-- RBAC: ROLE_PERMISSIONS
-- =============================================================================
CREATE TABLE role_permissions (
  role_id       UUID NOT NULL REFERENCES roles(id)       ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

-- =============================================================================
-- RBAC: USER_ROLES
-- =============================================================================
CREATE TABLE user_roles (
  user_id     UUID NOT NULL REFERENCES profiles(id)   ON DELETE CASCADE,
  role_id     UUID NOT NULL REFERENCES roles(id)      ON DELETE CASCADE,
  tenant_id   UUID NOT NULL REFERENCES tenants(id)    ON DELETE CASCADE,
  assigned_by UUID REFERENCES profiles(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at  TIMESTAMPTZ,
  PRIMARY KEY (user_id, role_id)
);

CREATE INDEX idx_user_roles_user   ON user_roles(user_id);
CREATE INDEX idx_user_roles_tenant ON user_roles(tenant_id);

-- =============================================================================
-- AUDIT LOG  (append-only, immutable via RLS)
-- =============================================================================
CREATE TABLE audit_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID REFERENCES tenants(id),
  user_id     UUID REFERENCES profiles(id),

  action      TEXT NOT NULL,    -- CREATE, UPDATE, DELETE, APPROVE, LOGIN, EXPORT
  module      TEXT NOT NULL,
  resource    TEXT NOT NULL,
  resource_id UUID,
  resource_ref TEXT,            -- human-readable ref (e.g. PO number)

  old_data    JSONB,
  new_data    JSONB,
  diff        JSONB,            -- computed diff

  ip_address  INET,
  user_agent  TEXT,
  session_id  TEXT,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_tenant    ON audit_logs(tenant_id, created_at DESC);
CREATE INDEX idx_audit_resource  ON audit_logs(resource, resource_id);
CREATE INDEX idx_audit_user      ON audit_logs(user_id, created_at DESC);

-- =============================================================================
-- ANNOUNCEMENTS / SYSTEM NOTIFICATIONS
-- =============================================================================
CREATE TABLE system_announcements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  target_type TEXT NOT NULL DEFAULT 'all',   -- 'all', 'rs', 'supplier', 'bank'
  priority    priority_level NOT NULL DEFAULT 'medium',
  starts_at   TIMESTAMPTZ,
  ends_at     TIMESTAMPTZ,
  created_by  UUID REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

-- TENANTS: only visible to own tenant or service role
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenants_self"
  ON tenants FOR ALL
  USING (is_service_role() OR id = current_tenant_id());

-- PROFILES: only own tenant
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_tenant"
  ON profiles FOR ALL
  USING (is_service_role() OR tenant_id = current_tenant_id());

-- ROLES: system roles (no tenant) + own tenant
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "roles_tenant"
  ON roles FOR ALL
  USING (is_service_role() OR tenant_id IS NULL OR tenant_id = current_tenant_id());

-- PERMISSIONS: readable by all authenticated
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "permissions_read_all"
  ON permissions FOR SELECT
  USING (auth.role() = 'authenticated');

-- ROLE_PERMISSIONS: readable by all authenticated
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "role_permissions_read_all"
  ON role_permissions FOR SELECT
  USING (auth.role() = 'authenticated');

-- USER_ROLES: own tenant
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_roles_tenant"
  ON user_roles FOR ALL
  USING (is_service_role() OR tenant_id = current_tenant_id());

-- AUDIT_LOGS: own tenant + read-only for non-service
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "audit_logs_tenant_read"
  ON audit_logs FOR SELECT
  USING (is_service_role() OR tenant_id = current_tenant_id());
CREATE POLICY "audit_logs_insert_only"
  ON audit_logs FOR INSERT
  WITH CHECK (TRUE);  -- insert allowed, no update/delete (append-only)

-- SYSTEM_ANNOUNCEMENTS: read by all authenticated
ALTER TABLE system_announcements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "announcements_read"
  ON system_announcements FOR SELECT
  USING (auth.role() = 'authenticated');

-- =============================================================================
-- HELPER: log_audit() — called from app or triggers
-- =============================================================================
CREATE OR REPLACE FUNCTION log_audit(
  p_action      TEXT,
  p_module      TEXT,
  p_resource    TEXT,
  p_resource_id UUID,
  p_old_data    JSONB DEFAULT NULL,
  p_new_data    JSONB DEFAULT NULL,
  p_resource_ref TEXT DEFAULT NULL
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id UUID := gen_random_uuid();
BEGIN
  INSERT INTO audit_logs (
    id, tenant_id, user_id,
    action, module, resource, resource_id, resource_ref,
    old_data, new_data
  ) VALUES (
    v_id,
    current_tenant_id(),
    auth.uid(),
    p_action, p_module, p_resource, p_resource_id, p_resource_ref,
    p_old_data, p_new_data
  );
  RETURN v_id;
END;
$$;

-- =============================================================================
-- END  00_foundation.sql
-- =============================================================================

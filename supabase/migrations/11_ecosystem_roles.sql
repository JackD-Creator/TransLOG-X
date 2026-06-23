-- =============================================================================
-- TransLOG-X  |  11_ecosystem_roles.sql
-- Ecosystem Role Tables: KSM Mitra, Distributor, Bank
-- Alur: RS → KSM Mitra → Distributor → Bank → AR/Payment
-- =============================================================================

-- =============================================================================
-- KSM CATALOG ITEMS
-- Item yang aktif dikelola/diprocure oleh KSM Mitra
-- Subset dari kfa_drugs + kfa_alkes yang mereka handle
-- =============================================================================
CREATE TABLE ksm_catalog_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,  -- KSM tenant

  kfa_code        TEXT NOT NULL,
  catalog_type    TEXT NOT NULL CHECK (catalog_type IN ('obat', 'alkes', 'bmhp')),
  name            TEXT NOT NULL,
  generic_name    TEXT,
  uom             TEXT NOT NULL DEFAULT 'pcs',
  storage_condition TEXT,
  is_fornas       BOOLEAN NOT NULL DEFAULT FALSE,
  is_narkotika    BOOLEAN NOT NULL DEFAULT FALSE,

  -- KSM internal
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  notes           TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}',

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, kfa_code)
);

CREATE INDEX idx_ksm_catalog_tenant   ON ksm_catalog_items(tenant_id);
CREATE INDEX idx_ksm_catalog_kfa      ON ksm_catalog_items(kfa_code);
CREATE INDEX idx_ksm_catalog_type     ON ksm_catalog_items(catalog_type);
CREATE INDEX idx_ksm_catalog_name     ON ksm_catalog_items USING gin(name gin_trgm_ops);

CREATE TRIGGER trg_ksm_catalog_updated_at
  BEFORE UPDATE ON ksm_catalog_items
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- SUPPLIER CATALOG ITEMS
-- Katalog produk milik Distributor: item yang mereka jual + harga + stok
-- =============================================================================
CREATE TABLE supplier_catalog_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,  -- Distributor tenant

  kfa_code        TEXT NOT NULL,
  catalog_type    TEXT NOT NULL CHECK (catalog_type IN ('obat', 'alkes', 'bmhp')),
  name            TEXT NOT NULL,
  brand_name      TEXT,
  manufacturer    TEXT,
  uom             TEXT NOT NULL DEFAULT 'pcs',
  nie             TEXT,

  -- Pricing
  hna_price       NUMERIC(15, 2),   -- Harga Netto Apotek
  sell_price      NUMERIC(15, 2) NOT NULL,
  min_order_qty   INT NOT NULL DEFAULT 1,
  min_order_uom   TEXT DEFAULT 'pcs',

  -- Availability
  stock_available INT NOT NULL DEFAULT 0,
  lead_time_days  INT NOT NULL DEFAULT 3,
  is_available    BOOLEAN NOT NULL DEFAULT TRUE,

  -- Terms
  payment_terms   payment_terms NOT NULL DEFAULT 'net_30',

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, kfa_code)
);

CREATE INDEX idx_sup_catalog_tenant   ON supplier_catalog_items(tenant_id);
CREATE INDEX idx_sup_catalog_kfa      ON supplier_catalog_items(kfa_code);
CREATE INDEX idx_sup_catalog_name     ON supplier_catalog_items USING gin(name gin_trgm_ops);
CREATE INDEX idx_sup_catalog_avail    ON supplier_catalog_items(is_available) WHERE is_available = TRUE;

CREATE TRIGGER trg_sup_catalog_updated_at
  BEFORE UPDATE ON supplier_catalog_items
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- SUPPLIER ITEM MAPPING
-- Relasi: KSM ↔ Distributor ↔ Item → harga negosiasi, preferred supplier
-- Dipakai saat KSM "Checking Supplier" sebelum buat PO
-- =============================================================================
CREATE TABLE supplier_item_mapping (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ksm_tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  supplier_tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

  kfa_code        TEXT NOT NULL,
  name            TEXT NOT NULL,

  -- Negotiated terms antara KSM dan Distributor
  negotiated_price  NUMERIC(15, 2),
  payment_terms     payment_terms NOT NULL DEFAULT 'net_30',
  lead_time_days    INT NOT NULL DEFAULT 3,
  min_order_qty     INT NOT NULL DEFAULT 1,

  is_preferred      BOOLEAN NOT NULL DEFAULT FALSE,  -- apakah ini supplier utama untuk item ini
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  contract_ref      TEXT,
  valid_until       DATE,

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (ksm_tenant_id, supplier_tenant_id, kfa_code)
);

CREATE INDEX idx_sim_ksm       ON supplier_item_mapping(ksm_tenant_id);
CREATE INDEX idx_sim_supplier  ON supplier_item_mapping(supplier_tenant_id);
CREATE INDEX idx_sim_kfa       ON supplier_item_mapping(kfa_code);
CREATE INDEX idx_sim_preferred ON supplier_item_mapping(ksm_tenant_id, kfa_code) WHERE is_preferred = TRUE;

CREATE TRIGGER trg_sim_updated_at
  BEFORE UPDATE ON supplier_item_mapping
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- HOSPITAL NOTIFICATIONS (Min Stock Alert)
-- RS → KSM Mitra: notifikasi ketika stok di bawah minimum
-- Trigger awal dari alur pengadaan
-- =============================================================================
CREATE TABLE hospital_notifications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rs_tenant_id    UUID NOT NULL REFERENCES tenants(id),    -- RS yang kirim notif
  ksm_tenant_id   UUID NOT NULL REFERENCES tenants(id),    -- KSM yang terima

  notif_number    TEXT NOT NULL UNIQUE,  -- e.g. NOTIF-2026-001
  notif_date      DATE NOT NULL DEFAULT CURRENT_DATE,

  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'acknowledged', 'po_created', 'completed', 'cancelled')),

  notes           TEXT,
  acknowledged_at TIMESTAMPTZ,
  acknowledged_by UUID REFERENCES profiles(id),

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hosp_notif_ksm    ON hospital_notifications(ksm_tenant_id, status);
CREATE INDEX idx_hosp_notif_rs     ON hospital_notifications(rs_tenant_id);
CREATE INDEX idx_hosp_notif_date   ON hospital_notifications(notif_date DESC);

CREATE TRIGGER trg_hosp_notif_updated_at
  BEFORE UPDATE ON hospital_notifications
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- HOSPITAL NOTIFICATION LINES
-- Detail item per notifikasi min stock
-- =============================================================================
CREATE TABLE hospital_notification_lines (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id   UUID NOT NULL REFERENCES hospital_notifications(id) ON DELETE CASCADE,

  kfa_code          TEXT NOT NULL,
  item_name         TEXT NOT NULL,
  catalog_type      TEXT NOT NULL CHECK (catalog_type IN ('obat', 'alkes', 'bmhp')),
  uom               TEXT NOT NULL,

  current_stock     INT NOT NULL DEFAULT 0,
  min_stock         INT NOT NULL DEFAULT 0,
  requested_qty     INT NOT NULL,
  approved_qty      INT,

  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hosp_notif_lines_notif ON hospital_notification_lines(notification_id);
CREATE INDEX idx_hosp_notif_lines_kfa   ON hospital_notification_lines(kfa_code);

-- =============================================================================
-- KSM PURCHASE ORDERS
-- PO dari KSM Mitra ke Distributor
-- Dibuat setelah checking supplier & konfirmasi notifikasi RS
-- =============================================================================
CREATE TABLE ksm_purchase_orders (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ksm_tenant_id   UUID NOT NULL REFERENCES tenants(id),
  supplier_tenant_id UUID NOT NULL REFERENCES tenants(id),
  rs_tenant_id    UUID REFERENCES tenants(id),   -- RS tujuan pengiriman
  notification_id UUID REFERENCES hospital_notifications(id),

  po_number       TEXT NOT NULL UNIQUE,   -- e.g. KSM-PO-2026-001
  po_date         DATE NOT NULL DEFAULT CURRENT_DATE,
  expected_delivery DATE,

  status          po_status NOT NULL DEFAULT 'draft',
  payment_terms   payment_terms NOT NULL DEFAULT 'net_30',

  -- Totals
  subtotal        NUMERIC(15, 2) NOT NULL DEFAULT 0,
  tax_amount      NUMERIC(15, 2) NOT NULL DEFAULT 0,
  total_amount    NUMERIC(15, 2) NOT NULL DEFAULT 0,

  -- Approval
  submitted_at    TIMESTAMPTZ,
  approved_at     TIMESTAMPTZ,
  approved_by     UUID REFERENCES profiles(id),
  sent_at         TIMESTAMPTZ,   -- PO dikirim ke Distributor

  notes           TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ksm_po_ksm        ON ksm_purchase_orders(ksm_tenant_id, status);
CREATE INDEX idx_ksm_po_supplier   ON ksm_purchase_orders(supplier_tenant_id, status);
CREATE INDEX idx_ksm_po_date       ON ksm_purchase_orders(po_date DESC);

CREATE TRIGGER trg_ksm_po_updated_at
  BEFORE UPDATE ON ksm_purchase_orders
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- KSM PO LINES
-- Line item dalam PO KSM ke Distributor
-- =============================================================================
CREATE TABLE ksm_po_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id           UUID NOT NULL REFERENCES ksm_purchase_orders(id) ON DELETE CASCADE,

  kfa_code        TEXT NOT NULL,
  item_name       TEXT NOT NULL,
  catalog_type    TEXT NOT NULL CHECK (catalog_type IN ('obat', 'alkes', 'bmhp')),
  uom             TEXT NOT NULL,

  ordered_qty     INT NOT NULL,
  received_qty    INT NOT NULL DEFAULT 0,
  unit_price      NUMERIC(15, 2) NOT NULL,
  tax_rate        NUMERIC(5, 2) NOT NULL DEFAULT 11.0,   -- PPN 11%
  line_total      NUMERIC(15, 2) NOT NULL,

  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ksm_po_lines_po  ON ksm_po_lines(po_id);
CREATE INDEX idx_ksm_po_lines_kfa ON ksm_po_lines(kfa_code);

CREATE TRIGGER trg_ksm_po_lines_updated_at
  BEFORE UPDATE ON ksm_po_lines
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- SCF FACILITIES (Bank)
-- Fasilitas pembiayaan yang diberikan Bank ke KSM Mitra atau RS
-- Term of Payment yang diaktifkan setelah notif invoice dari KSM
-- =============================================================================
CREATE TABLE scf_facilities (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_tenant_id    UUID NOT NULL REFERENCES tenants(id),
  borrower_tenant_id UUID NOT NULL REFERENCES tenants(id),  -- KSM atau RS

  facility_number   TEXT NOT NULL UNIQUE,
  financing_type    financing_type NOT NULL DEFAULT 'reverse_factoring',

  -- Limit & Terms
  facility_limit    NUMERIC(15, 2) NOT NULL,
  outstanding       NUMERIC(15, 2) NOT NULL DEFAULT 0,
  available_limit   NUMERIC(15, 2) GENERATED ALWAYS AS (facility_limit - outstanding) STORED,

  interest_rate_pa  NUMERIC(6, 4) NOT NULL,   -- bunga per tahun (e.g. 0.1200 = 12%)
  tenor_days        INT NOT NULL DEFAULT 30,
  payment_terms     payment_terms NOT NULL DEFAULT 'net_30',

  status            financing_status NOT NULL DEFAULT 'approved',

  -- Dates
  facility_start    DATE NOT NULL,
  facility_end      DATE NOT NULL,
  approved_at       TIMESTAMPTZ,
  approved_by       UUID REFERENCES profiles(id),

  -- Standing Instruction
  standing_instruction_active BOOLEAN NOT NULL DEFAULT FALSE,
  si_bank_account   TEXT,   -- rekening RS untuk auto-debit

  notes             TEXT,
  metadata          JSONB NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_scf_bank      ON scf_facilities(bank_tenant_id, status);
CREATE INDEX idx_scf_borrower  ON scf_facilities(borrower_tenant_id, status);

CREATE TRIGGER trg_scf_updated_at
  BEFORE UPDATE ON scf_facilities
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- AR ACCOUNTS (KSM Mitra di Bank)
-- Accounts Receivable KSM di Bank — dipakai untuk terima pembayaran dari Bank
-- setelah distributor dibayar, KSM kelola cicilan + bunga ke Bank
-- =============================================================================
CREATE TABLE ar_accounts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_tenant_id    UUID NOT NULL REFERENCES tenants(id),
  ksm_tenant_id     UUID NOT NULL REFERENCES tenants(id),
  facility_id       UUID REFERENCES scf_facilities(id),

  ar_number         TEXT NOT NULL UNIQUE,   -- e.g. AR-KSM-2026-001
  po_number         TEXT,                   -- ref ke ksm_purchase_orders.po_number
  invoice_ref       TEXT,                   -- nomor invoice dari Distributor

  -- Invoice details
  invoice_amount    NUMERIC(15, 2) NOT NULL,
  disbursed_amount  NUMERIC(15, 2) NOT NULL DEFAULT 0,  -- berapa yang dibayar Bank ke Distributor
  interest_amount   NUMERIC(15, 2) NOT NULL DEFAULT 0,
  total_payable     NUMERIC(15, 2) NOT NULL DEFAULT 0,  -- yang harus dibayar KSM ke Bank
  paid_amount       NUMERIC(15, 2) NOT NULL DEFAULT 0,
  outstanding_amount NUMERIC(15, 2) GENERATED ALWAYS AS (total_payable - paid_amount) STORED,

  -- Timeline
  invoice_date      DATE NOT NULL,
  disbursement_date DATE,     -- Bank bayar Distributor
  due_date          DATE NOT NULL,
  paid_date         DATE,

  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'disbursed', 'partially_paid', 'paid', 'overdue', 'defaulted')),

  -- Notif ke Bank
  notif_sent_at     TIMESTAMPTZ,
  top_activated_at  TIMESTAMPTZ,   -- Term of Payment diaktifkan Bank

  notes             TEXT,
  metadata          JSONB NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ar_bank     ON ar_accounts(bank_tenant_id, status);
CREATE INDEX idx_ar_ksm      ON ar_accounts(ksm_tenant_id, status);
CREATE INDEX idx_ar_due      ON ar_accounts(due_date) WHERE status NOT IN ('paid', 'defaulted');

CREATE TRIGGER trg_ar_updated_at
  BEFORE UPDATE ON ar_accounts
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- BPJS MONITORING (Bank)
-- Bank memantau cashflow BPJS ke rekening RS
-- Sebagai indikator kemampuan RS untuk bayar cicilan (via standing instruction)
-- =============================================================================
CREATE TABLE bpjs_payment_monitoring (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_tenant_id    UUID NOT NULL REFERENCES tenants(id),
  rs_tenant_id      UUID NOT NULL REFERENCES tenants(id),

  period_month      INT NOT NULL CHECK (period_month BETWEEN 1 AND 12),
  period_year       INT NOT NULL,

  -- Klaim yang diajukan RS ke BPJS (bukan untuk obat, tapi pelayanan kesehatan)
  claim_submitted   NUMERIC(15, 2) NOT NULL DEFAULT 0,
  claim_verified    NUMERIC(15, 2) NOT NULL DEFAULT 0,
  claim_approved    NUMERIC(15, 2) NOT NULL DEFAULT 0,
  claim_paid        NUMERIC(15, 2) NOT NULL DEFAULT 0,

  -- Pembayaran BPJS ke Rekening RS
  payment_date      DATE,
  payment_amount    NUMERIC(15, 2) NOT NULL DEFAULT 0,
  bank_account_rs   TEXT,

  -- Standing instruction: berapa yang dipotong untuk bayar Bank
  si_deducted       NUMERIC(15, 2) NOT NULL DEFAULT 0,
  si_reference      TEXT,

  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (bank_tenant_id, rs_tenant_id, period_year, period_month)
);

CREATE INDEX idx_bpjs_mon_bank ON bpjs_payment_monitoring(bank_tenant_id);
CREATE INDEX idx_bpjs_mon_rs   ON bpjs_payment_monitoring(rs_tenant_id);

CREATE TRIGGER trg_bpjs_mon_updated_at
  BEFORE UPDATE ON bpjs_payment_monitoring
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- RLS POLICIES
-- Setiap tabel hanya visible ke tenant yang relevan
-- =============================================================================

ALTER TABLE ksm_catalog_items           ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_catalog_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_item_mapping       ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_notifications      ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_notification_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE ksm_purchase_orders         ENABLE ROW LEVEL SECURITY;
ALTER TABLE ksm_po_lines                ENABLE ROW LEVEL SECURITY;
ALTER TABLE scf_facilities              ENABLE ROW LEVEL SECURITY;
ALTER TABLE ar_accounts                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE bpjs_payment_monitoring     ENABLE ROW LEVEL SECURITY;

-- KSM Catalog: visible ke KSM tenant sendiri
CREATE POLICY "ksm_catalog_tenant" ON ksm_catalog_items FOR ALL
  USING (is_service_role() OR tenant_id = current_tenant_id());

-- Supplier Catalog: visible ke supplier tenant sendiri + KSM (untuk checking supplier)
CREATE POLICY "sup_catalog_own" ON supplier_catalog_items FOR ALL
  USING (is_service_role() OR tenant_id = current_tenant_id());
CREATE POLICY "sup_catalog_ksm_read" ON supplier_catalog_items FOR SELECT
  USING (auth.role() = 'authenticated');  -- KSM bisa baca semua untuk checking supplier

-- Supplier Item Mapping: KSM dan Supplier yang relevan
CREATE POLICY "sim_ksm" ON supplier_item_mapping FOR ALL
  USING (is_service_role() OR ksm_tenant_id = current_tenant_id() OR supplier_tenant_id = current_tenant_id());

-- Hospital Notifications: RS dan KSM yang relevan
CREATE POLICY "hosp_notif_parties" ON hospital_notifications FOR ALL
  USING (is_service_role() OR rs_tenant_id = current_tenant_id() OR ksm_tenant_id = current_tenant_id());

CREATE POLICY "hosp_notif_lines_read" ON hospital_notification_lines FOR ALL
  USING (is_service_role() OR EXISTS (
    SELECT 1 FROM hospital_notifications n WHERE n.id = notification_id
    AND (n.rs_tenant_id = current_tenant_id() OR n.ksm_tenant_id = current_tenant_id())
  ));

-- KSM PO: KSM dan Supplier yang relevan
CREATE POLICY "ksm_po_parties" ON ksm_purchase_orders FOR ALL
  USING (is_service_role() OR ksm_tenant_id = current_tenant_id() OR supplier_tenant_id = current_tenant_id());

CREATE POLICY "ksm_po_lines_read" ON ksm_po_lines FOR ALL
  USING (is_service_role() OR EXISTS (
    SELECT 1 FROM ksm_purchase_orders po WHERE po.id = po_id
    AND (po.ksm_tenant_id = current_tenant_id() OR po.supplier_tenant_id = current_tenant_id())
  ));

-- SCF Facilities: Bank dan borrower
CREATE POLICY "scf_parties" ON scf_facilities FOR ALL
  USING (is_service_role() OR bank_tenant_id = current_tenant_id() OR borrower_tenant_id = current_tenant_id());

-- AR Accounts: Bank dan KSM
CREATE POLICY "ar_parties" ON ar_accounts FOR ALL
  USING (is_service_role() OR bank_tenant_id = current_tenant_id() OR ksm_tenant_id = current_tenant_id());

-- BPJS Monitoring: Bank saja
CREATE POLICY "bpjs_mon_bank" ON bpjs_payment_monitoring FOR ALL
  USING (is_service_role() OR bank_tenant_id = current_tenant_id());

-- =============================================================================
-- END  11_ecosystem_roles.sql
-- =============================================================================

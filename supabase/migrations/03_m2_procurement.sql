-- =============================================================================
-- TransLOG-X  |  03_m2_procurement.sql
-- M2: Procurement & Sourcing — supplier, PR, RFQ, quotation, PO, contract, budget
-- =============================================================================

-- =============================================================================
-- SUPPLIERS
-- =============================================================================
CREATE TABLE suppliers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

  -- Profil
  code              TEXT NOT NULL,
  name              TEXT NOT NULL,
  short_name        TEXT,
  type              TEXT NOT NULL DEFAULT 'pbf'
                    CHECK (type IN ('pbf','distributor','manufacturer','importir','apotek','lain_lain')),

  -- Legal
  npwp              TEXT,
  nib               TEXT,
  izin_pbf          TEXT,         -- izin PBF dari Kemenkes
  izin_expired_at   DATE,
  cdob_certified    BOOLEAN NOT NULL DEFAULT FALSE,
  cdob_cert_number  TEXT,
  cdob_expired_at   DATE,
  iso_certified     BOOLEAN NOT NULL DEFAULT FALSE,

  -- Kontak
  contact_name      TEXT,
  email             TEXT,
  phone             TEXT,
  website           TEXT,
  address           TEXT,
  city              TEXT,
  province          TEXT,
  postal_code       TEXT,

  -- Bank
  bank_name         TEXT,
  bank_account_no   TEXT,
  bank_account_name TEXT,

  -- Rating & terms
  payment_terms     payment_terms NOT NULL DEFAULT 'net_30',
  credit_limit      NUMERIC(18, 2),
  lead_time_days    INT NOT NULL DEFAULT 7,
  min_order_value   NUMERIC(15, 2),
  performance_score NUMERIC(3, 1) CHECK (performance_score BETWEEN 0 AND 5),

  -- KYC / Approval
  kyc_status        kyc_status NOT NULL DEFAULT 'not_started',
  kyc_verified_at   TIMESTAMPTZ,
  kyc_verified_by   UUID REFERENCES profiles(id),
  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','active','suspended','blacklisted')),

  is_preferred      BOOLEAN NOT NULL DEFAULT FALSE,
  is_lkpp           BOOLEAN NOT NULL DEFAULT FALSE,  -- terdaftar di e-Katalog LKPP

  metadata          JSONB NOT NULL DEFAULT '{}',
  created_by        UUID REFERENCES profiles(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, code)
);

CREATE INDEX idx_suppliers_tenant   ON suppliers(tenant_id);
CREATE INDEX idx_suppliers_name     ON suppliers USING gin(name gin_trgm_ops);
CREATE INDEX idx_suppliers_status   ON suppliers(tenant_id, status);
CREATE INDEX idx_suppliers_kyc      ON suppliers(tenant_id, kyc_status);

CREATE TRIGGER trg_suppliers_updated_at
  BEFORE UPDATE ON suppliers
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- FK back-patch: reorder_rules.preferred_supplier_id
ALTER TABLE reorder_rules
  ADD CONSTRAINT fk_reorder_supplier
  FOREIGN KEY (preferred_supplier_id) REFERENCES suppliers(id);

-- =============================================================================
-- SUPPLIER PRODUCTS  — katalog harga produk per supplier
-- =============================================================================
CREATE TABLE supplier_products (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  supplier_id     UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  product_id      UUID NOT NULL REFERENCES products(id),
  kfa_code        TEXT,

  supplier_sku    TEXT,         -- kode item di sisi supplier
  unit_price      NUMERIC(15, 4) NOT NULL,
  currency        currency_code NOT NULL DEFAULT 'IDR',
  uom             TEXT NOT NULL DEFAULT 'tablet',
  min_order_qty   NUMERIC(12, 4) NOT NULL DEFAULT 1,
  lead_time_days  INT NOT NULL DEFAULT 7,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  price_valid_until DATE,
  notes           TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, supplier_id, product_id)
);

CREATE INDEX idx_sup_products_supplier ON supplier_products(supplier_id);
CREATE INDEX idx_sup_products_product  ON supplier_products(product_id);

CREATE TRIGGER trg_sup_products_updated_at
  BEFORE UPDATE ON supplier_products
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- BUDGETS  — Anggaran pengadaan per periode per departemen
-- =============================================================================
CREATE TABLE budgets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  warehouse_id    UUID REFERENCES warehouses(id),

  name            TEXT NOT NULL,
  period_year     INT NOT NULL,
  period_month    INT CHECK (period_month BETWEEN 1 AND 12),  -- NULL = annual
  department      TEXT,
  category        product_category,

  total_amount    NUMERIC(18, 2) NOT NULL,
  used_amount     NUMERIC(18, 2) NOT NULL DEFAULT 0,
  reserved_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  available_amount NUMERIC(18, 2)
    GENERATED ALWAYS AS (total_amount - used_amount - reserved_amount) STORED,

  status          TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('draft','active','exhausted','cancelled')),

  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,
  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_budgets_tenant  ON budgets(tenant_id);
CREATE INDEX idx_budgets_period  ON budgets(tenant_id, period_year, period_month);
CREATE TRIGGER trg_budgets_updated_at
  BEFORE UPDATE ON budgets FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- PURCHASE REQUESTS (PR)
-- =============================================================================
CREATE TABLE purchase_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
  budget_id       UUID REFERENCES budgets(id),

  pr_number       TEXT NOT NULL,
  title           TEXT,
  status          approval_status NOT NULL DEFAULT 'draft',
  priority        priority_level NOT NULL DEFAULT 'medium',
  required_by     DATE,

  total_est_value NUMERIC(18, 2),
  notes           TEXT,
  trigger_type    TEXT DEFAULT 'manual'
                  CHECK (trigger_type IN ('manual','auto_reorder','min_stock','scheduled')),

  requested_by    UUID NOT NULL REFERENCES profiles(id),
  submitted_at    TIMESTAMPTZ,
  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,
  rejected_reason TEXT,

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, pr_number)
);

CREATE TABLE purchase_request_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  pr_id           UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
  product_id      UUID NOT NULL REFERENCES products(id),

  qty_requested   NUMERIC(12, 4) NOT NULL,
  uom             TEXT NOT NULL,
  est_unit_price  NUMERIC(15, 4),
  est_total       NUMERIC(18, 2),
  notes           TEXT,

  qty_on_order    NUMERIC(12, 4) NOT NULL DEFAULT 0,  -- sudah ter-PO
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pr_tenant     ON purchase_requests(tenant_id);
CREATE INDEX idx_pr_status     ON purchase_requests(tenant_id, status);
CREATE INDEX idx_pr_lines_pr   ON purchase_request_lines(pr_id);

CREATE TRIGGER trg_pr_updated_at
  BEFORE UPDATE ON purchase_requests
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- RFQ (Request for Quotation)
-- =============================================================================
CREATE TABLE rfqs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  pr_id           UUID REFERENCES purchase_requests(id),

  rfq_number      TEXT NOT NULL,
  title           TEXT,
  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft','sent','closed','cancelled')),

  deadline_at     TIMESTAMPTZ NOT NULL,
  notes           TEXT,
  terms           TEXT,

  created_by      UUID REFERENCES profiles(id),
  sent_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, rfq_number)
);

CREATE TABLE rfq_suppliers (
  rfq_id       UUID NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
  supplier_id  UUID NOT NULL REFERENCES suppliers(id),
  tenant_id    UUID NOT NULL REFERENCES tenants(id),
  invited_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  PRIMARY KEY (rfq_id, supplier_id)
);

CREATE TABLE rfq_lines (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rfq_id      UUID NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
  tenant_id   UUID NOT NULL REFERENCES tenants(id),
  product_id  UUID NOT NULL REFERENCES products(id),
  qty         NUMERIC(12, 4) NOT NULL,
  uom         TEXT NOT NULL,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_rfqs_updated_at
  BEFORE UPDATE ON rfqs FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE INDEX idx_rfqs_tenant ON rfqs(tenant_id);

-- =============================================================================
-- QUOTATIONS  — Penawaran dari supplier atas RFQ
-- =============================================================================
CREATE TABLE quotations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  rfq_id          UUID NOT NULL REFERENCES rfqs(id),
  supplier_id     UUID NOT NULL REFERENCES suppliers(id),

  quot_number     TEXT,
  status          TEXT NOT NULL DEFAULT 'received'
                  CHECK (status IN ('received','evaluating','selected','rejected','expired')),

  valid_until     DATE,
  payment_terms   payment_terms NOT NULL DEFAULT 'net_30',
  delivery_days   INT,
  notes           TEXT,
  total_value     NUMERIC(18, 2),

  submitted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  evaluated_at    TIMESTAMPTZ,
  selected_by     UUID REFERENCES profiles(id),

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE quotation_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_id    UUID NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  rfq_line_id     UUID REFERENCES rfq_lines(id),
  product_id      UUID NOT NULL REFERENCES products(id),

  qty_offered     NUMERIC(12, 4) NOT NULL,
  unit_price      NUMERIC(15, 4) NOT NULL,
  uom             TEXT NOT NULL,
  discount_pct    NUMERIC(5, 2) DEFAULT 0,
  total_price     NUMERIC(18, 2),
  lot_number      TEXT,
  expired_at      DATE,
  notes           TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_quotations_rfq     ON quotations(rfq_id);
CREATE INDEX idx_quotations_supplier ON quotations(supplier_id);
CREATE TRIGGER trg_quotations_updated_at
  BEFORE UPDATE ON quotations FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- PURCHASE ORDERS (PO)
-- =============================================================================
CREATE TABLE purchase_orders (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  supplier_id     UUID NOT NULL REFERENCES suppliers(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
  budget_id       UUID REFERENCES budgets(id),
  quotation_id    UUID REFERENCES quotations(id),
  pr_id           UUID REFERENCES purchase_requests(id),

  po_number       TEXT NOT NULL,
  status          po_status NOT NULL DEFAULT 'draft',
  priority        priority_level NOT NULL DEFAULT 'medium',

  order_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  expected_delivery DATE,
  payment_terms   payment_terms NOT NULL DEFAULT 'net_30',

  subtotal        NUMERIC(18, 2) NOT NULL DEFAULT 0,
  tax_amount      NUMERIC(18, 2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total_amount    NUMERIC(18, 2) NOT NULL DEFAULT 0,
  currency        currency_code NOT NULL DEFAULT 'IDR',

  shipping_address TEXT,
  notes           TEXT,
  terms_conditions TEXT,

  -- Approval chain
  submitted_by    UUID REFERENCES profiles(id),
  submitted_at    TIMESTAMPTZ,
  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,
  sent_at         TIMESTAMPTZ,    -- waktu PO dikirim ke supplier
  cancelled_at    TIMESTAMPTZ,
  cancelled_by    UUID REFERENCES profiles(id),
  cancel_reason   TEXT,

  -- BPOM serialization check
  requires_bpom_serial BOOLEAN NOT NULL DEFAULT FALSE,

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, po_number)
);

CREATE TABLE po_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  po_id           UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id      UUID NOT NULL REFERENCES products(id),
  pr_line_id      UUID REFERENCES purchase_request_lines(id),

  qty_ordered     NUMERIC(12, 4) NOT NULL,
  qty_received    NUMERIC(12, 4) NOT NULL DEFAULT 0,
  qty_pending     NUMERIC(12, 4) GENERATED ALWAYS AS (qty_ordered - qty_received) STORED,
  uom             TEXT NOT NULL,

  unit_price      NUMERIC(15, 4) NOT NULL,
  discount_pct    NUMERIC(5, 2) NOT NULL DEFAULT 0,
  tax_pct         NUMERIC(5, 2) NOT NULL DEFAULT 11,   -- PPN 11%
  line_total      NUMERIC(18, 2) NOT NULL,

  lot_number      TEXT,
  expired_at      DATE,
  notes           TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_po_tenant    ON purchase_orders(tenant_id);
CREATE INDEX idx_po_status    ON purchase_orders(tenant_id, status);
CREATE INDEX idx_po_supplier  ON purchase_orders(supplier_id);
CREATE INDEX idx_po_lines_po  ON po_lines(po_id);

CREATE TRIGGER trg_po_updated_at
  BEFORE UPDATE ON purchase_orders
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- CONTRACTS  — Kontrak jangka panjang dengan supplier
-- =============================================================================
CREATE TABLE contracts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  supplier_id     UUID NOT NULL REFERENCES suppliers(id),

  contract_number TEXT NOT NULL,
  title           TEXT NOT NULL,
  type            TEXT NOT NULL DEFAULT 'annual'
                  CHECK (type IN ('annual','framework','spot','consignment','lkpp')),
  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft','active','expired','terminated','renewed')),

  start_date      DATE NOT NULL,
  end_date        DATE NOT NULL,
  total_value     NUMERIC(18, 2),
  payment_terms   payment_terms NOT NULL DEFAULT 'net_30',

  auto_renew      BOOLEAN NOT NULL DEFAULT FALSE,
  renewal_notice_days INT DEFAULT 30,

  signed_by_tenant    UUID REFERENCES profiles(id),
  signed_by_supplier  TEXT,
  signed_at           DATE,

  document_url    TEXT,   -- Supabase Storage URL
  notes           TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}',

  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, contract_number)
);

CREATE INDEX idx_contracts_tenant   ON contracts(tenant_id);
CREATE INDEX idx_contracts_expiry   ON contracts(end_date) WHERE status = 'active';
CREATE TRIGGER trg_contracts_updated_at
  BEFORE UPDATE ON contracts FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================
ALTER TABLE suppliers            ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_products    ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets               ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_requests    ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_request_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfqs                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfq_suppliers         ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfq_lines             ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotations            ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotation_lines       ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders       ENABLE ROW LEVEL SECURITY;
ALTER TABLE po_lines              ENABLE ROW LEVEL SECURITY;
ALTER TABLE contracts             ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'suppliers', 'supplier_products', 'budgets',
    'purchase_requests', 'purchase_request_lines',
    'rfqs', 'rfq_suppliers', 'rfq_lines',
    'quotations', 'quotation_lines',
    'purchase_orders', 'po_lines', 'contracts'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;

-- =============================================================================
-- END  03_m2_procurement.sql
-- =============================================================================

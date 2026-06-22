-- =============================================================================
-- TransLOG-X  |  06_m5_financial.sql
-- M5: Financial & Payment — invoice, payment, SCF (reverse factoring,
--     invoice financing, dynamic discounting, BPJS bridging, PO financing)
-- =============================================================================

-- =============================================================================
-- BANK ACCOUNTS  — Rekening bank tenant
-- =============================================================================
CREATE TABLE bank_accounts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  bank_name       TEXT NOT NULL,
  bank_code       TEXT,             -- kode bank BI
  branch          TEXT,
  account_number  TEXT NOT NULL,
  account_name    TEXT NOT NULL,
  currency        currency_code NOT NULL DEFAULT 'IDR',

  account_type    TEXT NOT NULL DEFAULT 'current'
                  CHECK (account_type IN ('current','savings','escrow','va','collection')),

  is_primary      BOOLEAN NOT NULL DEFAULT FALSE,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  snap_enabled    BOOLEAN NOT NULL DEFAULT FALSE,  -- terdaftar di SNAP BI

  current_balance NUMERIC(18, 2),
  last_synced_at  TIMESTAMPTZ,

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, account_number)
);

CREATE INDEX idx_bank_accounts_tenant ON bank_accounts(tenant_id);
CREATE TRIGGER trg_bank_accounts_updated_at
  BEFORE UPDATE ON bank_accounts
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- INVOICES  — AP (payable ke supplier) & AR (receivable dari BPJS/RS)
-- =============================================================================
CREATE TABLE invoices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  invoice_number  TEXT NOT NULL,
  direction       TEXT NOT NULL CHECK (direction IN ('payable','receivable')),

  -- Counterparty
  supplier_id     UUID REFERENCES suppliers(id),      -- untuk AP
  customer_name   TEXT,                               -- untuk AR

  -- Source documents
  po_id           UUID REFERENCES purchase_orders(id),
  grn_id          UUID REFERENCES goods_receipts(id),

  status          invoice_status NOT NULL DEFAULT 'draft',
  payment_terms   payment_terms NOT NULL DEFAULT 'net_30',

  invoice_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  due_date        DATE NOT NULL,

  subtotal        NUMERIC(18, 2) NOT NULL DEFAULT 0,
  ppn_pct         NUMERIC(5, 2) NOT NULL DEFAULT 11,   -- PPN 11%
  ppn_amount      NUMERIC(18, 2) NOT NULL DEFAULT 0,
  pph_pct         NUMERIC(5, 2) NOT NULL DEFAULT 0,    -- PPh sesuai jenis transaksi
  pph_amount      NUMERIC(18, 2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total_amount    NUMERIC(18, 2) NOT NULL DEFAULT 0,
  paid_amount     NUMERIC(18, 2) NOT NULL DEFAULT 0,
  outstanding     NUMERIC(18, 2)
    GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
  currency        currency_code NOT NULL DEFAULT 'IDR',

  -- e-Faktur / Coretax
  efaktur_number  TEXT UNIQUE,      -- nomor faktur pajak
  coretax_ref     TEXT,             -- referensi Coretax DJP
  efaktur_status  TEXT DEFAULT 'pending'
                  CHECK (efaktur_status IN ('pending','submitted','approved','rejected','amended')),

  -- Matching
  matched_at      TIMESTAMPTZ,      -- 3-way matching completed
  matched_by      UUID REFERENCES profiles(id),

  notes           TEXT,
  document_url    TEXT,             -- scan invoice (Supabase Storage)
  metadata        JSONB NOT NULL DEFAULT '{}',

  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, invoice_number)
);

CREATE TABLE invoice_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  invoice_id      UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  product_id      UUID REFERENCES products(id),
  description     TEXT NOT NULL,

  qty             NUMERIC(12, 4) NOT NULL,
  uom             TEXT,
  unit_price      NUMERIC(15, 4) NOT NULL,
  discount_pct    NUMERIC(5, 2) NOT NULL DEFAULT 0,
  tax_pct         NUMERIC(5, 2) NOT NULL DEFAULT 11,
  line_total      NUMERIC(18, 2) NOT NULL,

  po_line_id      UUID REFERENCES po_lines(id),
  grn_line_id     UUID REFERENCES grn_lines(id),

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoices_tenant    ON invoices(tenant_id);
CREATE INDEX idx_invoices_status    ON invoices(tenant_id, status);
CREATE INDEX idx_invoices_due       ON invoices(due_date) WHERE status NOT IN ('paid','cancelled');
CREATE INDEX idx_invoices_supplier  ON invoices(supplier_id);
CREATE INDEX idx_invoice_lines      ON invoice_lines(invoice_id);

CREATE TRIGGER trg_invoices_updated_at
  BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- PAYMENTS
-- =============================================================================
CREATE TABLE payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  payment_number  TEXT NOT NULL,
  direction       TEXT NOT NULL CHECK (direction IN ('outgoing','incoming')),

  invoice_id      UUID REFERENCES invoices(id),
  bank_account_id UUID REFERENCES bank_accounts(id),

  amount          NUMERIC(18, 2) NOT NULL,
  currency        currency_code NOT NULL DEFAULT 'IDR',
  method          payment_method NOT NULL DEFAULT 'bank_transfer',

  payment_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','processing','completed','failed','reversed')),

  reference_no    TEXT,     -- nomor referensi bank / SNAP
  snap_ref        TEXT,     -- SNAP transaction reference
  bank_statement_id UUID,   -- FK to bank_statements (set in M8)

  notes           TEXT,
  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, payment_number)
);

CREATE INDEX idx_payments_tenant  ON payments(tenant_id);
CREATE INDEX idx_payments_invoice ON payments(invoice_id);
CREATE INDEX idx_payments_status  ON payments(tenant_id, status);

CREATE TRIGGER trg_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- FINANCING FACILITIES  — Fasilitas SCF (reverse factoring, invoice financing, dll)
-- Disetujui oleh bank / fintech (partner lender)
-- =============================================================================
CREATE TABLE financing_facilities (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),  -- borrower (RS / supplier)
  lender_tenant_id UUID REFERENCES tenants(id),          -- bank / fintech (bisa NULL jika external)
  lender_name     TEXT,                                  -- nama bank/fintech jika external

  facility_number TEXT NOT NULL,
  type            financing_type NOT NULL,
  status          financing_status NOT NULL DEFAULT 'draft',

  credit_limit    NUMERIC(18, 2) NOT NULL,
  used_amount     NUMERIC(18, 2) NOT NULL DEFAULT 0,
  available_amount NUMERIC(18, 2)
    GENERATED ALWAYS AS (credit_limit - used_amount) STORED,
  currency        currency_code NOT NULL DEFAULT 'IDR',

  interest_rate   NUMERIC(6, 4),     -- annual rate, misal 0.12 = 12%
  fee_pct         NUMERIC(5, 4),     -- origination fee
  tenor_days      INT,               -- default tenor per drawdown
  ltv_pct         NUMERIC(5, 2),     -- Loan-to-Value untuk inventory financing

  facility_start  DATE NOT NULL,
  facility_end    DATE NOT NULL,

  -- OJK compliance (P2P lending)
  ojk_registered  BOOLEAN NOT NULL DEFAULT FALSE,
  ojk_reg_number  TEXT,
  borrower_risk_grade TEXT,          -- A, B, C, D, E

  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,
  agreement_url   TEXT,              -- Supabase Storage

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, facility_number)
);

-- =============================================================================
-- FINANCING TRANSACTIONS  — Drawdown & repayment per invoice/PO
-- =============================================================================
CREATE TABLE financing_transactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  facility_id     UUID NOT NULL REFERENCES financing_facilities(id),

  tx_number       TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('drawdown','repayment','fee','interest','penalty')),
  status          financing_status NOT NULL DEFAULT 'submitted',

  -- Source asset being financed
  invoice_id      UUID REFERENCES invoices(id),
  po_id           UUID REFERENCES purchase_orders(id),
  bpjs_claim_id   UUID,                -- FK to bpjs_claims (set in M7)

  -- Amounts
  face_value      NUMERIC(18, 2) NOT NULL,   -- nilai invoice/PO
  advance_rate    NUMERIC(5, 2) NOT NULL DEFAULT 80,  -- advance % (misal 80%)
  disbursed_amount NUMERIC(18, 2),
  fee_amount      NUMERIC(18, 2),
  interest_amount NUMERIC(18, 2),
  repaid_amount   NUMERIC(18, 2) NOT NULL DEFAULT 0,
  outstanding_amount NUMERIC(18, 2),

  disbursed_at    TIMESTAMPTZ,
  due_date        DATE,
  repaid_at       TIMESTAMPTZ,
  tenor_days      INT,

  bank_account_id UUID REFERENCES bank_accounts(id),

  notes           TEXT,
  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,
  metadata        JSONB NOT NULL DEFAULT '{}',

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, tx_number)
);

CREATE INDEX idx_facilities_tenant  ON financing_facilities(tenant_id);
CREATE INDEX idx_facilities_status  ON financing_facilities(tenant_id, status);
CREATE INDEX idx_fin_tx_tenant      ON financing_transactions(tenant_id);
CREATE INDEX idx_fin_tx_facility    ON financing_transactions(facility_id);
CREATE INDEX idx_fin_tx_invoice     ON financing_transactions(invoice_id);
CREATE INDEX idx_fin_tx_due         ON financing_transactions(due_date)
  WHERE status NOT IN ('fully_repaid','rejected','cancelled');

CREATE TRIGGER trg_facilities_updated_at
  BEFORE UPDATE ON financing_facilities
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_fin_tx_updated_at
  BEFORE UPDATE ON financing_transactions
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================
ALTER TABLE bank_accounts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices              ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_lines         ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments              ENABLE ROW LEVEL SECURITY;
ALTER TABLE financing_facilities  ENABLE ROW LEVEL SECURITY;
ALTER TABLE financing_transactions ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'bank_accounts','invoices','invoice_lines',
    'payments','financing_facilities','financing_transactions'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;

-- =============================================================================
-- END  06_m5_financial.sql
-- =============================================================================

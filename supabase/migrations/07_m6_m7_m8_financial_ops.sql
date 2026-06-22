-- =============================================================================
-- TransLOG-X  |  07_m6_m7_m8_financial_ops.sql
-- M6: Credit & Risk Management
-- M7: Revenue Cycle Management (BPJS)
-- M8: Cash Flow & Treasury
-- =============================================================================


-- =============================================================================
-- M6: CREDIT & RISK MANAGEMENT
-- =============================================================================

CREATE TABLE credit_assessments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),   -- assessor (lender/fintech)
  subject_tenant_id UUID NOT NULL REFERENCES tenants(id), -- RS or supplier being scored

  assessment_number TEXT NOT NULL,
  assessment_type TEXT NOT NULL DEFAULT 'onboarding'
                  CHECK (assessment_type IN ('onboarding','periodic','trigger','renewal')),
  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft','in_progress','completed','expired')),

  -- SLIK OJK
  slik_inquiry_date DATE,
  slik_result       TEXT,
  slik_score        INT,

  -- Internal scoring
  financial_score   NUMERIC(5, 2),    -- 0-100
  operational_score NUMERIC(5, 2),
  compliance_score  NUMERIC(5, 2),
  overall_score     NUMERIC(5, 2),
  risk_grade        TEXT CHECK (risk_grade IN ('A','B','C','D','E')),

  -- Output
  recommended_limit NUMERIC(18, 2),
  approved_limit    NUMERIC(18, 2),
  interest_rate     NUMERIC(6, 4),
  tenor_days        INT,

  assessed_by       UUID REFERENCES profiles(id),
  assessed_at       TIMESTAMPTZ,
  valid_until       DATE,
  notes             TEXT,
  raw_data          JSONB NOT NULL DEFAULT '{}',

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, assessment_number)
);

CREATE TABLE credit_limits (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),        -- lender
  borrower_tenant_id UUID NOT NULL REFERENCES tenants(id),     -- borrower
  facility_id     UUID REFERENCES financing_facilities(id),
  assessment_id   UUID REFERENCES credit_assessments(id),

  limit_type      financing_type NOT NULL,
  total_limit     NUMERIC(18, 2) NOT NULL,
  used_amount     NUMERIC(18, 2) NOT NULL DEFAULT 0,
  reserved_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  available_amount NUMERIC(18, 2)
    GENERATED ALWAYS AS (total_limit - used_amount - reserved_amount) STORED,

  currency        currency_code NOT NULL DEFAULT 'IDR',
  interest_rate   NUMERIC(6, 4),
  valid_from      DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_until     DATE NOT NULL,

  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE risk_alerts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  subject_tenant_id UUID REFERENCES tenants(id),

  alert_type      TEXT NOT NULL,      -- 'overdue_payment','limit_exceeded','score_drop','slik_change'
  severity        priority_level NOT NULL DEFAULT 'medium',
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','acknowledged','resolved','false_positive')),

  title           TEXT NOT NULL,
  description     TEXT,
  trigger_value   NUMERIC(18, 4),
  threshold_value NUMERIC(18, 4),

  acknowledged_by UUID REFERENCES profiles(id),
  acknowledged_at TIMESTAMPTZ,
  resolved_by     UUID REFERENCES profiles(id),
  resolved_at     TIMESTAMPTZ,
  resolution_note TEXT,

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_credit_assess_tenant  ON credit_assessments(tenant_id);
CREATE INDEX idx_credit_limits_borrower ON credit_limits(borrower_tenant_id);
CREATE INDEX idx_risk_alerts_tenant    ON risk_alerts(tenant_id, status);

CREATE TRIGGER trg_credit_assess_updated_at
  BEFORE UPDATE ON credit_assessments
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_credit_limits_updated_at
  BEFORE UPDATE ON credit_limits
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_risk_alerts_updated_at
  BEFORE UPDATE ON risk_alerts
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- =============================================================================
-- M7: REVENUE CYCLE MANAGEMENT — BPJS Kesehatan Claims
-- =============================================================================

CREATE TABLE bpjs_claims (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  claim_number    TEXT NOT NULL,
  claim_type      TEXT NOT NULL DEFAULT 'rawat_inap'
                  CHECK (claim_type IN ('rawat_inap','rawat_jalan','igd','kronis','bayi_baru_lahir')),
  status          claim_status NOT NULL DEFAULT 'draft',

  -- Patient
  bpjs_card_no    TEXT NOT NULL,
  sep_number      TEXT,                -- Surat Eligibilitas Peserta
  patient_name    TEXT,
  admission_date  DATE NOT NULL,
  discharge_date  DATE,

  -- Diagnosis & coding
  primary_icd10   TEXT NOT NULL,
  secondary_icd10 TEXT[],
  primary_icd9cm  TEXT,               -- procedure code
  drg_code        TEXT,               -- iDRG code (berlaku Oktober 2025)
  drg_name        TEXT,
  drg_severity    INT CHECK (drg_severity BETWEEN 1 AND 5),

  -- Financial
  claimed_amount  NUMERIC(18, 2) NOT NULL,
  approved_amount NUMERIC(18, 2),
  paid_amount     NUMERIC(18, 2) NOT NULL DEFAULT 0,
  disputed_amount NUMERIC(18, 2),

  -- Financing link (BPJS bridging)
  financing_tx_id UUID REFERENCES financing_transactions(id),

  -- BPJS VClaim API
  vclaim_submission_at TIMESTAMPTZ,
  vclaim_ref_no        TEXT,
  vclaim_response      JSONB,

  -- Dates
  submitted_at    TIMESTAMPTZ,
  verified_at     TIMESTAMPTZ,
  approved_at     TIMESTAMPTZ,
  paid_at         TIMESTAMPTZ,

  -- Rejection/appeal
  rejection_code  TEXT,
  rejection_reason TEXT,
  appeal_deadline DATE,
  appeal_submitted_at TIMESTAMPTZ,
  appeal_status   TEXT CHECK (appeal_status IN ('pending','accepted','rejected')),

  notes           TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, claim_number)
);

-- Financing FK back-patch
ALTER TABLE financing_transactions
  ADD CONSTRAINT fk_fin_tx_bpjs_claim
  FOREIGN KEY (bpjs_claim_id) REFERENCES bpjs_claims(id);

CREATE TABLE bpjs_claim_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  claim_id        UUID NOT NULL REFERENCES bpjs_claims(id) ON DELETE CASCADE,
  product_id      UUID REFERENCES products(id),

  item_type       TEXT NOT NULL DEFAULT 'obat'
                  CHECK (item_type IN ('obat','alkes','bmhp','tindakan','jasa_medis','kamar')),
  description     TEXT NOT NULL,
  quantity        NUMERIC(12, 4) NOT NULL,
  uom             TEXT,
  unit_price      NUMERIC(15, 4),
  claimed_amount  NUMERIC(18, 2) NOT NULL,
  approved_amount NUMERIC(18, 2),
  rejection_code  TEXT,
  notes           TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bpjs_claims_tenant ON bpjs_claims(tenant_id);
CREATE INDEX idx_bpjs_claims_status ON bpjs_claims(tenant_id, status);
CREATE INDEX idx_bpjs_claims_card   ON bpjs_claims(bpjs_card_no);
CREATE INDEX idx_bpjs_claim_items   ON bpjs_claim_items(claim_id);

CREATE TRIGGER trg_bpjs_claims_updated_at
  BEFORE UPDATE ON bpjs_claims
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- =============================================================================
-- M8: CASH FLOW & TREASURY
-- =============================================================================

CREATE TABLE bank_statements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  bank_account_id UUID NOT NULL REFERENCES bank_accounts(id),

  statement_date  DATE NOT NULL,
  period_start    DATE NOT NULL,
  period_end      DATE NOT NULL,

  opening_balance NUMERIC(18, 2) NOT NULL,
  closing_balance NUMERIC(18, 2) NOT NULL,
  total_debit     NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total_credit    NUMERIC(18, 2) NOT NULL DEFAULT 0,

  source          TEXT DEFAULT 'manual'
                  CHECK (source IN ('manual','bank_api','snap','upload')),
  reconciled      BOOLEAN NOT NULL DEFAULT FALSE,
  reconciled_at   TIMESTAMPTZ,
  reconciled_by   UUID REFERENCES profiles(id),

  document_url    TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, bank_account_id, period_start, period_end)
);

CREATE TABLE bank_statement_lines (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants(id),
  statement_id      UUID NOT NULL REFERENCES bank_statements(id) ON DELETE CASCADE,

  transaction_date  DATE NOT NULL,
  value_date        DATE,
  description       TEXT NOT NULL,
  reference_no      TEXT,
  debit_amount      NUMERIC(18, 2) NOT NULL DEFAULT 0,
  credit_amount     NUMERIC(18, 2) NOT NULL DEFAULT 0,
  balance           NUMERIC(18, 2),

  -- Reconciliation
  matched_payment_id UUID REFERENCES payments(id),
  match_status      TEXT DEFAULT 'unmatched'
                    CHECK (match_status IN ('unmatched','matched','partial','exception')),

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE cash_forecasts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  bank_account_id UUID REFERENCES bank_accounts(id),

  forecast_date   DATE NOT NULL,
  forecast_period TEXT NOT NULL DEFAULT '13_week'
                  CHECK (forecast_period IN ('daily','weekly','13_week','monthly','quarterly')),

  opening_balance NUMERIC(18, 2) NOT NULL,

  -- Inflows
  inflow_bpjs     NUMERIC(18, 2) NOT NULL DEFAULT 0,
  inflow_financing NUMERIC(18, 2) NOT NULL DEFAULT 0,
  inflow_other    NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total_inflow    NUMERIC(18, 2) NOT NULL DEFAULT 0,

  -- Outflows
  outflow_suppliers    NUMERIC(18, 2) NOT NULL DEFAULT 0,
  outflow_repayment    NUMERIC(18, 2) NOT NULL DEFAULT 0,
  outflow_opex         NUMERIC(18, 2) NOT NULL DEFAULT 0,
  outflow_other        NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total_outflow        NUMERIC(18, 2) NOT NULL DEFAULT 0,

  net_cash_flow   NUMERIC(18, 2)
    GENERATED ALWAYS AS (total_inflow - total_outflow) STORED,
  closing_balance NUMERIC(18, 2)
    GENERATED ALWAYS AS (opening_balance + total_inflow - total_outflow) STORED,

  -- AI confidence
  confidence_score NUMERIC(4, 2),   -- 0.00 - 1.00
  model_version   TEXT,

  generated_by    TEXT DEFAULT 'ai'
                  CHECK (generated_by IN ('ai','manual','hybrid')),
  scenario        TEXT DEFAULT 'base'
                  CHECK (scenario IN ('base','optimistic','pessimistic','stress')),

  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Working capital KPIs — computed daily by Edge Function
CREATE TABLE wc_metrics (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  metric_date     DATE NOT NULL,

  -- Core WC metrics (in days)
  dso_days        NUMERIC(6, 2),    -- Days Sales Outstanding
  dpo_days        NUMERIC(6, 2),    -- Days Payable Outstanding
  dio_days        NUMERIC(6, 2),    -- Days Inventory Outstanding
  ccc_days        NUMERIC(6, 2),    -- Cash Conversion Cycle = DIO + DSO - DPO

  -- Balances
  total_ar        NUMERIC(18, 2),   -- total receivable
  total_ap        NUMERIC(18, 2),   -- total payable
  total_inventory_value NUMERIC(18, 2),
  cash_on_hand    NUMERIC(18, 2),

  -- BPJS specific
  bpjs_outstanding_claims NUMERIC(18, 2),
  bpjs_avg_payment_days   NUMERIC(6, 2),

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, metric_date)
);

CREATE INDEX idx_bank_statements_tenant ON bank_statements(tenant_id);
CREATE INDEX idx_bank_st_lines_stmt     ON bank_statement_lines(statement_id);
CREATE INDEX idx_cash_forecasts_tenant  ON cash_forecasts(tenant_id, forecast_date DESC);
CREATE INDEX idx_wc_metrics_tenant      ON wc_metrics(tenant_id, metric_date DESC);

CREATE TRIGGER trg_bank_statements_updated_at
  BEFORE UPDATE ON bank_statements
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_cash_forecasts_updated_at
  BEFORE UPDATE ON cash_forecasts
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================
ALTER TABLE credit_assessments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_limits        ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_alerts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE bpjs_claims          ENABLE ROW LEVEL SECURITY;
ALTER TABLE bpjs_claim_items     ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_statements      ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_statement_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_forecasts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE wc_metrics           ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'credit_assessments','credit_limits','risk_alerts',
    'bpjs_claims','bpjs_claim_items',
    'bank_statements','bank_statement_lines',
    'cash_forecasts','wc_metrics'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;

-- =============================================================================
-- END  07_m6_m7_m8_financial_ops.sql
-- =============================================================================

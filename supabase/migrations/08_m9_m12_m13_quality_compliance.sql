-- =============================================================================
-- TransLOG-X  |  08_m9_m12_m13_quality_compliance.sql
-- M9:  Quality Management System (CAPA, deviation, training, complaint)
-- M12: Compliance, Audit & Regulasi (BPOM TTAC, CDOB, OJK, SNARS)
-- M13: KYC/KYB & Anti-Fraud
-- =============================================================================


-- =============================================================================
-- M9: QUALITY MANAGEMENT SYSTEM
-- =============================================================================

CREATE TABLE deviations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  warehouse_id    UUID REFERENCES warehouses(id),

  deviation_number TEXT NOT NULL,
  title           TEXT NOT NULL,
  description     TEXT NOT NULL,
  category        TEXT NOT NULL DEFAULT 'storage'
                  CHECK (category IN ('storage','temperature','transport','documentation','process','personnel','equipment')),
  severity        priority_level NOT NULL DEFAULT 'medium',
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','under_review','capa_assigned','capa_in_progress','closed','rejected')),

  -- Source
  source_type     TEXT,   -- 'audit','complaint','inspection','self_detection'
  source_id       UUID,

  product_id      UUID REFERENCES products(id),
  lot_id          UUID REFERENCES stock_lots(id),

  detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  detected_by     UUID REFERENCES profiles(id),
  closed_at       TIMESTAMPTZ,
  closed_by       UUID REFERENCES profiles(id),

  root_cause      TEXT,
  immediate_action TEXT,
  notes           TEXT,
  evidence_urls   TEXT[] DEFAULT '{}',

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, deviation_number)
);

CREATE TABLE capa_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  deviation_id    UUID REFERENCES deviations(id),

  capa_number     TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('corrective','preventive')),
  status          TEXT NOT NULL DEFAULT 'planned'
                  CHECK (status IN ('planned','in_progress','completed','verified','closed','overdue')),

  title           TEXT NOT NULL,
  description     TEXT NOT NULL,
  root_cause      TEXT,
  action_plan     TEXT NOT NULL,

  assigned_to     UUID REFERENCES profiles(id),
  due_date        DATE NOT NULL,
  completed_at    TIMESTAMPTZ,
  verified_at     TIMESTAMPTZ,
  verified_by     UUID REFERENCES profiles(id),

  effectiveness_score INT CHECK (effectiveness_score BETWEEN 1 AND 5),
  effectiveness_notes TEXT,
  evidence_urls   TEXT[] DEFAULT '{}',

  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, capa_number)
);

CREATE TABLE training_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  training_code   TEXT NOT NULL,
  title           TEXT NOT NULL,
  category        TEXT DEFAULT 'gdp'
                  CHECK (category IN ('gdp','cdob','sop','safety','compliance','product','it')),
  description     TEXT,
  trainer         TEXT,
  training_date   DATE NOT NULL,
  duration_hours  NUMERIC(4, 1),
  location        TEXT,
  document_url    TEXT,

  status          TEXT NOT NULL DEFAULT 'planned'
                  CHECK (status IN ('planned','completed','cancelled')),
  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, training_code)
);

CREATE TABLE training_participants (
  training_id   UUID NOT NULL REFERENCES training_records(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES profiles(id),
  tenant_id     UUID NOT NULL REFERENCES tenants(id),
  attended      BOOLEAN NOT NULL DEFAULT FALSE,
  score         NUMERIC(5, 2),
  passed        BOOLEAN,
  cert_url      TEXT,
  PRIMARY KEY (training_id, user_id)
);

CREATE TABLE complaints (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  complaint_number TEXT NOT NULL,
  source          TEXT NOT NULL DEFAULT 'internal'
                  CHECK (source IN ('internal','customer','regulator','supplier')),
  category        TEXT NOT NULL
                  CHECK (category IN ('quality','delivery','invoice','service','product','documentation','other')),
  severity        priority_level NOT NULL DEFAULT 'medium',
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','investigating','resolved','closed','escalated')),

  subject         TEXT NOT NULL,
  description     TEXT NOT NULL,
  product_id      UUID REFERENCES products(id),
  lot_id          UUID REFERENCES stock_lots(id),

  reported_by     UUID REFERENCES profiles(id),
  reported_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_to     UUID REFERENCES profiles(id),
  resolved_at     TIMESTAMPTZ,
  resolution      TEXT,

  deviation_id    UUID REFERENCES deviations(id),
  capa_id         UUID REFERENCES capa_records(id),

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, complaint_number)
);

CREATE INDEX idx_deviations_tenant ON deviations(tenant_id);
CREATE INDEX idx_capa_tenant       ON capa_records(tenant_id);
CREATE INDEX idx_capa_due          ON capa_records(due_date) WHERE status NOT IN ('closed','verified');
CREATE INDEX idx_complaints_tenant ON complaints(tenant_id);

CREATE TRIGGER trg_deviations_updated_at
  BEFORE UPDATE ON deviations FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_capa_updated_at
  BEFORE UPDATE ON capa_records FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_complaints_updated_at
  BEFORE UPDATE ON complaints FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_training_updated_at
  BEFORE UPDATE ON training_records FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- =============================================================================
-- M12: COMPLIANCE, AUDIT & REGULASI
-- =============================================================================

-- BPOM TTAC Serialization tracking
CREATE TABLE bpom_serializations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  lot_id          UUID REFERENCES stock_lots(id),
  product_id      UUID REFERENCES products(id),

  serial_number   TEXT NOT NULL UNIQUE,    -- nomor seri dari BPOM TTAC
  batch_number    TEXT,
  product_nie     TEXT,

  event_type      TEXT NOT NULL
                  CHECK (event_type IN ('packaging','shipping','receiving','dispensing','return','destruction','export')),
  event_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  aggregation_id  TEXT,    -- ID parent (box/karton)
  parent_serial   TEXT,    -- serial box/pallet

  bpom_submitted  BOOLEAN NOT NULL DEFAULT FALSE,
  bpom_response   JSONB,
  bpom_submitted_at TIMESTAMPTZ,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bpom_serial_tenant  ON bpom_serializations(tenant_id);
CREATE INDEX idx_bpom_serial_product ON bpom_serializations(product_id, event_at DESC);

-- Audit Findings
CREATE TABLE audit_findings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  audit_type      TEXT NOT NULL
                  CHECK (audit_type IN ('bpom','cdob','iso','snars','kars','ojk','internal','lkpp','bpjs')),
  finding_number  TEXT NOT NULL,
  title           TEXT NOT NULL,
  description     TEXT NOT NULL,
  category        TEXT,
  severity        priority_level NOT NULL DEFAULT 'medium',
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','capa_assigned','resolved','closed','waived')),

  auditor         TEXT,
  audit_date      DATE NOT NULL,
  due_date        DATE,

  capa_id         UUID REFERENCES capa_records(id),
  resolved_at     TIMESTAMPTZ,
  evidence_url    TEXT,
  notes           TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, finding_number)
);

-- Regulatory Reports (OJK, BI, DJP, Kemenkes)
CREATE TABLE regulatory_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  report_type     TEXT NOT NULL,   -- 'ojk_monthly','bpom_annual','djp_spt','kemenkes_lkh'
  period_start    DATE NOT NULL,
  period_end      DATE NOT NULL,
  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft','review','submitted','accepted','rejected','amended')),

  regulator       TEXT NOT NULL,   -- 'OJK','BPOM','DJP','Kemenkes','BI'
  submission_deadline DATE,
  submitted_at    TIMESTAMPTZ,
  submission_ref  TEXT,
  response        JSONB,

  document_url    TEXT,
  notes           TEXT,
  prepared_by     UUID REFERENCES profiles(id),
  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_findings_tenant ON audit_findings(tenant_id);
CREATE INDEX idx_reg_reports_tenant    ON regulatory_reports(tenant_id);
CREATE INDEX idx_reg_reports_deadline  ON regulatory_reports(submission_deadline)
  WHERE status = 'draft';

CREATE TRIGGER trg_audit_findings_updated_at
  BEFORE UPDATE ON audit_findings FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_reg_reports_updated_at
  BEFORE UPDATE ON regulatory_reports FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- =============================================================================
-- M13: KYC/KYB & ANTI-FRAUD
-- =============================================================================

CREATE TABLE kyc_verifications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),   -- verifier (platform)
  subject_type    TEXT NOT NULL CHECK (subject_type IN ('profile','tenant','supplier')),
  subject_id      UUID NOT NULL,

  verification_number TEXT NOT NULL,
  kyc_level       TEXT NOT NULL DEFAULT 'basic'
                  CHECK (kyc_level IN ('basic','enhanced','full')),
  status          kyc_status NOT NULL DEFAULT 'not_started',

  -- eKYC Dukcapil
  nik             TEXT,
  nik_match       BOOLEAN,
  biometric_match BOOLEAN,
  dukcapil_ref    TEXT,
  dukcapil_checked_at TIMESTAMPTZ,

  -- Business KYB
  nib_verified    BOOLEAN,
  npwp_verified   BOOLEAN,
  ojk_slik_checked BOOLEAN,
  slik_score      INT,

  -- PEP / Sanctions screening
  pep_checked     BOOLEAN NOT NULL DEFAULT FALSE,
  pep_match       BOOLEAN,
  sanctions_match BOOLEAN,
  screening_provider TEXT,
  screening_at    TIMESTAMPTZ,

  -- Result
  risk_level      TEXT DEFAULT 'low' CHECK (risk_level IN ('low','medium','high','very_high','rejected')),
  verified_at     TIMESTAMPTZ,
  verified_by     UUID REFERENCES profiles(id),
  expires_at      DATE,
  rejection_reason TEXT,

  raw_response    JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, verification_number)
);

CREATE TABLE fraud_alerts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  alert_number    TEXT NOT NULL,
  alert_type      TEXT NOT NULL
                  CHECK (alert_type IN (
                    'invoice_fraud','bpjs_fraud','collusion','duplicate_payment',
                    'vendor_impersonation','account_takeover','unusual_behavior',
                    'price_manipulation','quantity_mismatch'
                  )),
  severity        priority_level NOT NULL DEFAULT 'high',
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','investigating','confirmed','false_positive','closed')),

  -- Source
  source_type     TEXT,  -- 'invoice','bpjs_claim','payment','grn','po'
  source_id       UUID,
  source_ref      TEXT,

  -- ML model
  model_name      TEXT,
  model_score     NUMERIC(5, 4),   -- 0.0000 - 1.0000 fraud probability
  model_version   TEXT,
  features        JSONB NOT NULL DEFAULT '{}',

  description     TEXT NOT NULL,
  amount_at_risk  NUMERIC(18, 2),

  assigned_to     UUID REFERENCES profiles(id),
  investigated_by UUID REFERENCES profiles(id),
  resolved_at     TIMESTAMPTZ,
  resolution      TEXT,

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, alert_number)
);

CREATE TABLE fraud_cases (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  case_number     TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','investigating','escalated','closed_confirmed','closed_cleared')),

  title           TEXT NOT NULL,
  description     TEXT,
  total_amount    NUMERIC(18, 2),
  recovered_amount NUMERIC(18, 2),

  alert_ids       UUID[] DEFAULT '{}',

  case_manager    UUID REFERENCES profiles(id),
  opened_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at       TIMESTAMPTZ,
  report_url      TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, case_number)
);

CREATE INDEX idx_kyc_tenant    ON kyc_verifications(tenant_id);
CREATE INDEX idx_kyc_subject   ON kyc_verifications(subject_type, subject_id);
CREATE INDEX idx_fraud_alerts_tenant ON fraud_alerts(tenant_id, status);
CREATE INDEX idx_fraud_cases_tenant  ON fraud_cases(tenant_id);

CREATE TRIGGER trg_kyc_updated_at
  BEFORE UPDATE ON kyc_verifications FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_fraud_alerts_updated_at
  BEFORE UPDATE ON fraud_alerts FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_fraud_cases_updated_at
  BEFORE UPDATE ON fraud_cases FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================
DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'deviations','capa_records','training_records','training_participants','complaints',
    'bpom_serializations','audit_findings','regulatory_reports',
    'kyc_verifications','fraud_alerts','fraud_cases'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;

-- =============================================================================
-- END  08_m9_m12_m13_quality_compliance.sql
-- =============================================================================

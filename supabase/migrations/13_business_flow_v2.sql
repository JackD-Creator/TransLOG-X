-- =============================================================================
-- TransLOG-X  |  13_business_flow_v2.sql
-- Alur bisnis yang benar:
-- 1. SIMRS auto-notif → RS Procurement + KSM
-- 2. KSM konfirmasi pengiriman ke RS (bukan RS yang PO)
-- 3. Invoice auto H+1 setelah barang diterima benar
-- 4. SI bank custodian, BPJS payment, shortfall = bunga harian 50/50
-- =============================================================================


-- =============================================================================
-- 1. ALTER hospital_notifications: tambah kolom untuk SIMRS source & KSM konfirmasi
-- =============================================================================

ALTER TABLE hospital_notifications
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'simrs'
    CHECK (source IN ('simrs', 'manual', 'api')),
  ADD COLUMN IF NOT EXISTS ksm_confirmation_status TEXT DEFAULT NULL
    CHECK (ksm_confirmation_status IN (NULL, 'pending_rs_approval', 'rs_approved', 'rs_rejected')),
  ADD COLUMN IF NOT EXISTS ksm_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rs_approved_at TIMESTAMPTZ;

COMMENT ON COLUMN hospital_notifications.source IS 'simrs = otomatis dari SIMRS internal RS';
COMMENT ON COLUMN hospital_notifications.ksm_confirmation_status IS 'KSM kirim konfirmasi pengiriman → RS approve/reject';


-- =============================================================================
-- 2. Tabel INVOICES KSM → RS (auto-generated H+1 setelah barang diterima)
-- =============================================================================

CREATE TABLE IF NOT EXISTS ksm_invoices (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ksm_tenant_id     UUID NOT NULL REFERENCES tenants(id),
  rs_tenant_id      UUID NOT NULL REFERENCES tenants(id),
  po_id             UUID NOT NULL REFERENCES ksm_purchase_orders(id),

  invoice_number    TEXT NOT NULL UNIQUE,
  invoice_date      DATE NOT NULL,
  due_date          DATE NOT NULL,

  -- Dari PO
  subtotal          NUMERIC(15,2) NOT NULL,
  tax_amount        NUMERIC(15,2) NOT NULL,
  total_amount      NUMERIC(15,2) NOT NULL,

  -- Status
  status            TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'reviewed', 'sent_to_rs', 'acknowledged_rs', 'payment_pending', 'partially_paid', 'paid', 'overdue', 'disputed')),

  -- KSM review
  reviewed_at       TIMESTAMPTZ,
  reviewed_by       UUID REFERENCES profiles(id),
  sent_to_rs_at     TIMESTAMPTZ,

  -- Payment tracking
  paid_amount       NUMERIC(15,2) NOT NULL DEFAULT 0,
  outstanding       NUMERIC(15,2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,

  -- BPJS & kontrak
  contract_payment_days INT NOT NULL DEFAULT 30,
  bpjs_claim_ref    TEXT,
  bpjs_expected_date DATE,
  bpjs_received_date DATE,
  bpjs_amount       NUMERIC(15,2),

  -- Shortfall (kekurangan yang dicover bank)
  shortfall_amount  NUMERIC(15,2) NOT NULL DEFAULT 0,
  shortfall_covered_by_bank BOOLEAN NOT NULL DEFAULT FALSE,
  shortfall_facility_id UUID REFERENCES scf_facilities(id),

  notes             TEXT,
  metadata          JSONB NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ksm_inv_ksm ON ksm_invoices(ksm_tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_ksm_inv_rs ON ksm_invoices(rs_tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_ksm_inv_po ON ksm_invoices(po_id);
CREATE INDEX IF NOT EXISTS idx_ksm_inv_due ON ksm_invoices(due_date);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_ksm_inv_updated_at') THEN
    CREATE TRIGGER trg_ksm_inv_updated_at
      BEFORE UPDATE ON ksm_invoices
      FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
  END IF;
END $$;


-- =============================================================================
-- 3. Tabel DAILY INTEREST — bunga harian untuk shortfall, 50% KSM 50% RS
-- =============================================================================

CREATE TABLE IF NOT EXISTS daily_interest_accruals (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id        UUID NOT NULL REFERENCES ksm_invoices(id),
  facility_id       UUID NOT NULL REFERENCES scf_facilities(id),

  accrual_date      DATE NOT NULL,
  outstanding_principal NUMERIC(15,2) NOT NULL,
  daily_rate        NUMERIC(10,8) NOT NULL,
  interest_amount   NUMERIC(15,2) NOT NULL,

  -- Split 50/50
  ksm_share         NUMERIC(15,2) GENERATED ALWAYS AS (ROUND(interest_amount * 0.50, 2)) STORED,
  rs_share          NUMERIC(15,2) GENERATED ALWAYS AS (ROUND(interest_amount * 0.50, 2)) STORED,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(invoice_id, accrual_date)
);

CREATE INDEX IF NOT EXISTS idx_dia_invoice ON daily_interest_accruals(invoice_id);
CREATE INDEX IF NOT EXISTS idx_dia_date ON daily_interest_accruals(accrual_date);


-- =============================================================================
-- 4. Tabel STANDING INSTRUCTIONS — RS set SI di bank custodian
-- =============================================================================

CREATE TABLE IF NOT EXISTS standing_instructions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rs_tenant_id      UUID NOT NULL REFERENCES tenants(id),
  bank_tenant_id    UUID NOT NULL REFERENCES tenants(id),
  ksm_tenant_id     UUID NOT NULL REFERENCES tenants(id),

  si_number         TEXT NOT NULL UNIQUE,
  si_type           TEXT NOT NULL DEFAULT 'bpjs_auto_transfer'
    CHECK (si_type IN ('bpjs_auto_transfer', 'manual_transfer', 'escrow')),

  -- Bank account info
  rs_account_number TEXT NOT NULL,
  ksm_account_number TEXT NOT NULL,
  custodian_bank    TEXT NOT NULL,

  -- Terms
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  activated_at      TIMESTAMPTZ,
  deactivated_at    TIMESTAMPTZ,

  notes             TEXT,
  metadata          JSONB NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_si_rs ON standing_instructions(rs_tenant_id, is_active);


-- =============================================================================
-- 5. RLS untuk tabel baru
-- =============================================================================

ALTER TABLE ksm_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_interest_accruals ENABLE ROW LEVEL SECURITY;
ALTER TABLE standing_instructions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ksm_inv_parties" ON ksm_invoices FOR ALL
  USING (is_service_role() OR ksm_tenant_id = current_tenant_id() OR rs_tenant_id = current_tenant_id());

CREATE POLICY "dia_read" ON daily_interest_accruals FOR ALL
  USING (is_service_role() OR EXISTS (
    SELECT 1 FROM ksm_invoices i WHERE i.id = invoice_id
    AND (i.ksm_tenant_id = current_tenant_id() OR i.rs_tenant_id = current_tenant_id())
  ));

CREATE POLICY "si_parties" ON standing_instructions FOR ALL
  USING (is_service_role() OR rs_tenant_id = current_tenant_id()
    OR bank_tenant_id = current_tenant_id() OR ksm_tenant_id = current_tenant_id());


-- =============================================================================
-- 6. RPC: Auto-create invoice H+1 setelah PO fully_received
-- Dipanggil oleh trigger atau cron. Buat invoice + set due date dari kontrak.
-- =============================================================================

CREATE OR REPLACE FUNCTION auto_create_invoice_after_receipt(p_po_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_po        ksm_purchase_orders%ROWTYPE;
  v_inv_id    UUID;
  v_inv_num   TEXT;
  v_due_date  DATE;
  v_contract_days INT := 30;
BEGIN
  SELECT * INTO v_po FROM ksm_purchase_orders WHERE id = p_po_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'PO tidak ditemukan'; END IF;
  IF v_po.status != 'fully_received' THEN
    RAISE EXCEPTION 'PO harus fully_received, saat ini: %', v_po.status;
  END IF;

  -- Cek apakah invoice sudah ada
  IF EXISTS (SELECT 1 FROM ksm_invoices WHERE po_id = p_po_id) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Invoice sudah ada untuk PO ini');
  END IF;

  -- Generate invoice number
  v_inv_num := 'INV-KSM-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(
    (SELECT COALESCE(MAX(CAST(RIGHT(invoice_number, 6) AS INT)), 0) + 1
     FROM ksm_invoices WHERE invoice_number LIKE 'INV-KSM-%')::TEXT, 6, '0');

  -- Due date = H+1 (invoice date) + contract days
  v_due_date := (CURRENT_DATE + 1) + v_contract_days;

  INSERT INTO ksm_invoices (
    ksm_tenant_id, rs_tenant_id, po_id,
    invoice_number, invoice_date, due_date,
    subtotal, tax_amount, total_amount,
    status, contract_payment_days,
    metadata
  ) VALUES (
    v_po.ksm_tenant_id, v_po.rs_tenant_id, p_po_id,
    v_inv_num, CURRENT_DATE + 1, v_due_date,
    v_po.subtotal, v_po.tax_amount, v_po.total_amount,
    'draft', v_contract_days,
    jsonb_build_object(
      'po_number', v_po.po_number,
      'rs_name', COALESCE(v_po.metadata->>'rs_name', ''),
      'supplier_name', COALESCE(v_po.metadata->>'supplier_name', ''),
      'auto_generated', true,
      'generated_at', NOW()::TEXT
    )
  ) RETURNING id INTO v_inv_id;

  RETURN jsonb_build_object(
    'success', true,
    'invoice_id', v_inv_id,
    'invoice_number', v_inv_num,
    'invoice_date', (CURRENT_DATE + 1)::TEXT,
    'due_date', v_due_date::TEXT,
    'total_amount', v_po.total_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 7. TRIGGER: Auto invoice saat PO fully_received
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_auto_invoice_on_receipt()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'fully_received' AND OLD.status != 'fully_received' THEN
    PERFORM auto_create_invoice_after_receipt(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_auto_invoice ON ksm_purchase_orders;
CREATE TRIGGER trg_auto_invoice
  AFTER UPDATE OF status ON ksm_purchase_orders
  FOR EACH ROW EXECUTE FUNCTION fn_auto_invoice_on_receipt();


-- =============================================================================
-- 8. RPC: KSM review invoice & kirim ke RS
-- =============================================================================

CREATE OR REPLACE FUNCTION ksm_review_and_send_invoice(p_invoice_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_inv ksm_invoices%ROWTYPE;
BEGIN
  SELECT * INTO v_inv FROM ksm_invoices WHERE id = p_invoice_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Invoice tidak ditemukan'; END IF;
  IF v_inv.status NOT IN ('draft', 'reviewed') THEN
    RAISE EXCEPTION 'Invoice harus draft/reviewed, saat ini: %', v_inv.status;
  END IF;

  UPDATE ksm_invoices SET
    status = 'sent_to_rs',
    reviewed_at = NOW(),
    sent_to_rs_at = NOW()
  WHERE id = p_invoice_id;

  RETURN jsonb_build_object(
    'success', true,
    'invoice_id', p_invoice_id,
    'invoice_number', v_inv.invoice_number,
    'status', 'sent_to_rs'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 9. RPC: KSM kirim konfirmasi pengiriman ke RS (dari notifikasi)
-- RS harus approve dulu sebelum KSM buat PO
-- =============================================================================

CREATE OR REPLACE FUNCTION ksm_send_delivery_confirmation(p_notif_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_notif hospital_notifications%ROWTYPE;
BEGIN
  SELECT * INTO v_notif FROM hospital_notifications WHERE id = p_notif_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Notifikasi tidak ditemukan'; END IF;
  IF v_notif.status != 'acknowledged' THEN
    RAISE EXCEPTION 'Notifikasi harus acknowledged, saat ini: %', v_notif.status;
  END IF;
  IF COALESCE(v_notif.metadata->>'supplier_check', '') != 'confirmed' THEN
    RAISE EXCEPTION 'Supplier belum konfirmasi ketersediaan';
  END IF;

  UPDATE hospital_notifications SET
    ksm_confirmation_status = 'pending_rs_approval',
    ksm_confirmed_at = NOW(),
    metadata = v_notif.metadata || jsonb_build_object(
      'ksm_confirmation_sent', true,
      'ksm_confirmation_at', NOW()::TEXT
    )
  WHERE id = p_notif_id;

  RETURN jsonb_build_object(
    'success', true,
    'notif_id', p_notif_id,
    'confirmation_status', 'pending_rs_approval'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 10. RPC: RS approve/reject konfirmasi KSM
-- =============================================================================

CREATE OR REPLACE FUNCTION rs_respond_to_ksm_confirmation(
  p_notif_id UUID,
  p_approved BOOLEAN,
  p_reason TEXT DEFAULT ''
)
RETURNS JSONB AS $$
DECLARE
  v_notif hospital_notifications%ROWTYPE;
BEGIN
  SELECT * INTO v_notif FROM hospital_notifications WHERE id = p_notif_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Notifikasi tidak ditemukan'; END IF;
  IF v_notif.ksm_confirmation_status != 'pending_rs_approval' THEN
    RAISE EXCEPTION 'Tidak ada konfirmasi KSM yang menunggu approval';
  END IF;

  IF p_approved THEN
    UPDATE hospital_notifications SET
      ksm_confirmation_status = 'rs_approved',
      rs_approved_at = NOW(),
      metadata = v_notif.metadata || jsonb_build_object('rs_approved', true, 'rs_approved_at', NOW()::TEXT)
    WHERE id = p_notif_id;
  ELSE
    UPDATE hospital_notifications SET
      ksm_confirmation_status = 'rs_rejected',
      metadata = v_notif.metadata || jsonb_build_object('rs_rejected', true, 'rs_reject_reason', p_reason)
    WHERE id = p_notif_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'notif_id', p_notif_id,
    'approved', p_approved
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 11. RPC: Proses pembayaran BPJS → SI auto-transfer → shortfall handling
-- =============================================================================

CREATE OR REPLACE FUNCTION process_bpjs_payment(
  p_invoice_id UUID,
  p_bpjs_amount NUMERIC(15,2),
  p_bpjs_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
  v_inv         ksm_invoices%ROWTYPE;
  v_shortfall   NUMERIC(15,2);
  v_si          standing_instructions%ROWTYPE;
BEGIN
  SELECT * INTO v_inv FROM ksm_invoices WHERE id = p_invoice_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Invoice tidak ditemukan'; END IF;

  -- Update BPJS info
  v_shortfall := GREATEST(0, v_inv.total_amount - p_bpjs_amount);

  UPDATE ksm_invoices SET
    bpjs_amount = p_bpjs_amount,
    bpjs_received_date = p_bpjs_date,
    paid_amount = p_bpjs_amount,
    shortfall_amount = v_shortfall,
    status = CASE
      WHEN v_shortfall <= 0 THEN 'paid'
      ELSE 'partially_paid'
    END,
    metadata = v_inv.metadata || jsonb_build_object(
      'bpjs_received', true,
      'bpjs_date', p_bpjs_date::TEXT,
      'bpjs_amount', p_bpjs_amount,
      'shortfall', v_shortfall
    )
  WHERE id = p_invoice_id;

  -- Jika ada shortfall → tandai untuk fasilitas kredit bank
  IF v_shortfall > 0 THEN
    -- Cari SI aktif untuk RS ini
    SELECT * INTO v_si FROM standing_instructions
      WHERE rs_tenant_id = v_inv.rs_tenant_id AND is_active = true
      LIMIT 1;

    -- Cari fasilitas SCF untuk cover shortfall
    UPDATE ksm_invoices SET
      shortfall_covered_by_bank = TRUE,
      shortfall_facility_id = (
        SELECT id FROM scf_facilities
        WHERE borrower_tenant_id = v_inv.ksm_tenant_id
        AND status = 'approved'
        AND available_limit >= v_shortfall
        LIMIT 1
      ),
      metadata = metadata || jsonb_build_object(
        'shortfall_bank_cover', true,
        'daily_interest_active', true,
        'interest_split', '50% KSM / 50% RS',
        'si_active', v_si.id IS NOT NULL
      )
    WHERE id = p_invoice_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'invoice_id', p_invoice_id,
    'bpjs_amount', p_bpjs_amount,
    'shortfall', v_shortfall,
    'status', CASE WHEN v_shortfall <= 0 THEN 'paid' ELSE 'partially_paid' END,
    'bank_cover_needed', v_shortfall > 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 12. RPC: Hitung bunga harian untuk shortfall
-- Dipanggil harian oleh cron/scheduler
-- =============================================================================

CREATE OR REPLACE FUNCTION accrue_daily_interest(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
  v_inv       RECORD;
  v_rate      NUMERIC(10,8);
  v_interest  NUMERIC(15,2);
  v_count     INT := 0;
BEGIN
  FOR v_inv IN
    SELECT i.id AS invoice_id, i.shortfall_amount, i.shortfall_facility_id,
           f.interest_rate_pa
    FROM ksm_invoices i
    JOIN scf_facilities f ON f.id = i.shortfall_facility_id
    WHERE i.shortfall_amount > 0
    AND i.shortfall_covered_by_bank = TRUE
    AND i.status IN ('partially_paid', 'overdue')
    AND NOT EXISTS (
      SELECT 1 FROM daily_interest_accruals d
      WHERE d.invoice_id = i.id AND d.accrual_date = p_date
    )
  LOOP
    v_rate := v_inv.interest_rate_pa / 365.0;
    v_interest := ROUND(v_inv.shortfall_amount * v_rate, 2);

    INSERT INTO daily_interest_accruals (
      invoice_id, facility_id, accrual_date,
      outstanding_principal, daily_rate, interest_amount
    ) VALUES (
      v_inv.invoice_id, v_inv.shortfall_facility_id, p_date,
      v_inv.shortfall_amount, v_rate, v_interest
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'date', p_date::TEXT,
    'invoices_accrued', v_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT EXECUTE ON FUNCTION auto_create_invoice_after_receipt(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION ksm_review_and_send_invoice(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION ksm_send_delivery_confirmation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rs_respond_to_ksm_confirmation(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION process_bpjs_payment(UUID, NUMERIC, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION accrue_daily_interest(DATE) TO authenticated;

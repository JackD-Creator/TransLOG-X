-- =============================================================================
-- 15_financial_rpc.sql
-- RPC functions untuk semua halaman keuangan KSM
-- Dipanggil oleh Go serverless handlers → frontend via apiGet
-- =============================================================================

-- =============================================================================
-- 1. CASH FLOW
-- =============================================================================
CREATE OR REPLACE FUNCTION get_ksm_cashflow(
  p_ksm_tenant_id UUID,
  p_date_from      DATE,
  p_date_to        DATE
)
RETURNS JSONB AS $$
DECLARE
  v_rate             NUMERIC;
  v_data_start       DATE := '2025-12-01';
  v_kas_masuk_bpjs   NUMERIC := 0;
  v_kas_masuk_sf     NUMERIC := 0;
  v_scf_principal    NUMERIC := 0;
  v_scf_interest     NUMERIC := 0;
  v_sf_interest      NUMERIC := 0;
  v_saldo_awal       NUMERIC := 0;
  v_prev_in          NUMERIC := 0;
  v_prev_out         NUMERIC := 0;
BEGIN
  SELECT COALESCE(interest_rate_pa, 0.11) INTO v_rate
  FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved' LIMIT 1;

  -- Kas masuk periode
  SELECT
    COALESCE(SUM(bpjs_amount), 0),
    COALESCE(SUM(CASE WHEN shortfall_covered_by_bank THEN shortfall_amount ELSE 0 END), 0)
  INTO v_kas_masuk_bpjs, v_kas_masuk_sf
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND status IN ('paid','partially_paid')
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  -- Kas keluar: SCF dari ar_accounts
  SELECT COALESCE(SUM(disbursed_amount),0), COALESCE(SUM(interest_amount),0)
  INTO v_scf_principal, v_scf_interest
  FROM ar_accounts
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  -- Fallback COGS jika ar_accounts kosong untuk periode ini
  IF v_scf_principal = 0 THEN
    SELECT COALESCE(SUM((total_amount / 1.11) * 0.88), 0) INTO v_scf_principal
    FROM ksm_invoices
    WHERE ksm_tenant_id = p_ksm_tenant_id
      AND status IN ('paid','partially_paid')
      AND invoice_date BETWEEN p_date_from AND p_date_to;
    v_scf_interest := ROUND(v_scf_principal * (v_rate / 12.0), 0);
  END IF;

  -- Bunga shortfall 50% KSM = shortfall_amount × rate/365 × hari × 0.5
  SELECT COALESCE(SUM(
    ROUND(shortfall_amount * (v_rate / 365.0) *
      GREATEST(0, p_date_to - invoice_date) * 0.5, 0)
  ), 0) INTO v_sf_interest
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND shortfall_covered_by_bank = TRUE AND shortfall_amount > 0
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  -- Saldo awal kumulatif
  SELECT
    COALESCE(SUM(bpjs_amount),0) + COALESCE(SUM(CASE WHEN shortfall_covered_by_bank THEN shortfall_amount ELSE 0 END),0)
  INTO v_prev_in
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id AND status IN ('paid','partially_paid')
    AND invoice_date >= v_data_start AND invoice_date < p_date_from;

  SELECT COALESCE(SUM(disbursed_amount + interest_amount),0) INTO v_prev_out
  FROM ar_accounts
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND invoice_date >= v_data_start AND invoice_date < p_date_from;

  v_saldo_awal := GREATEST(0, v_prev_in - v_prev_out - (v_prev_in * 0.04));

  RETURN jsonb_build_object(
    'kas_masuk_bpjs',       v_kas_masuk_bpjs,
    'kas_masuk_shortfall',  v_kas_masuk_sf,
    'scf_principal',        v_scf_principal,
    'scf_interest',         v_scf_interest,
    'shortfall_interest_ksm', v_sf_interest,
    'saldo_awal',           v_saldo_awal,
    'interest_rate_pa',     v_rate
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 2. P&L
-- =============================================================================
CREATE OR REPLACE FUNCTION get_ksm_pl(
  p_ksm_tenant_id UUID,
  p_date_from      DATE,
  p_date_to        DATE
)
RETURNS JSONB AS $$
DECLARE
  v_rate          NUMERIC;
  v_revenue       NUMERIC := 0;
  v_revenue_ppn   NUMERIC := 0;
  v_cogs          NUMERIC := 0;
  v_scf_interest  NUMERIC := 0;
  v_sf_interest   NUMERIC := 0;
BEGIN
  SELECT COALESCE(interest_rate_pa, 0.11) INTO v_rate
  FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved' LIMIT 1;

  -- Revenue = invoice paid dalam periode
  SELECT COALESCE(SUM(total_amount),0), COALESCE(SUM(tax_amount),0)
  INTO v_revenue, v_revenue_ppn
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND (status = 'paid' OR (status = 'partially_paid' AND shortfall_covered_by_bank = TRUE))
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  -- COGS dari ar_accounts
  SELECT COALESCE(SUM(disbursed_amount),0), COALESCE(SUM(interest_amount),0)
  INTO v_cogs, v_scf_interest
  FROM ar_accounts
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  -- Fallback COGS
  IF v_cogs = 0 AND v_revenue > 0 THEN
    v_cogs        := ROUND((v_revenue - v_revenue_ppn) * 0.88, 0);
    v_scf_interest := ROUND(v_cogs * (v_rate / 12.0), 0);
  END IF;

  -- Bunga shortfall KSM 50%
  SELECT COALESCE(SUM(
    ROUND(shortfall_amount * (v_rate / 365.0) * GREATEST(0, p_date_to - invoice_date) * 0.5, 0)
  ), 0) INTO v_sf_interest
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND shortfall_covered_by_bank = TRUE AND shortfall_amount > 0
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  DECLARE
    v_netto      NUMERIC := v_revenue - v_revenue_ppn;
    v_gp         NUMERIC := v_netto - v_cogs;
    v_opex       NUMERIC := ROUND(v_netto * 0.04, 0);
    v_ebit       NUMERIC := v_gp - v_opex;
    v_ebt        NUMERIC := v_ebit - (v_scf_interest + v_sf_interest);
    v_tax        NUMERIC := CASE WHEN v_ebt > 0 THEN ROUND(v_ebt * 0.22, 0) ELSE 0 END;
  BEGIN
    RETURN jsonb_build_object(
      'revenue',              v_revenue,
      'revenue_ppn',          v_revenue_ppn,
      'revenue_netto',        v_netto,
      'cogs',                 v_cogs,
      'gross_profit',         v_gp,
      'gross_margin',         CASE WHEN v_netto > 0 THEN ROUND(v_gp / v_netto * 100, 2) ELSE 0 END,
      'opex',                 v_opex,
      'scf_interest',         v_scf_interest,
      'shortfall_interest_ksm', v_sf_interest,
      'total_interest',       v_scf_interest + v_sf_interest,
      'ebit',                 v_ebit,
      'ebt',                  v_ebt,
      'tax',                  v_tax,
      'net_income',           v_ebt - v_tax,
      'net_margin',           CASE WHEN v_netto > 0 THEN ROUND((v_ebt - v_tax) / v_netto * 100, 2) ELSE 0 END
    );
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 3. BALANCE SHEET
-- =============================================================================
CREATE OR REPLACE FUNCTION get_ksm_balance_sheet(p_ksm_tenant_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_rate         NUMERIC;
  v_ar_rs        NUMERIC := 0;
  v_hutang_scf   NUMERIC := 0;
  v_transit      NUMERIC := 0;
  v_interest_acc NUMERIC := 0;
  v_scf_paid     NUMERIC := 0;
  v_scf_disbursed NUMERIC := 0;
BEGIN
  SELECT COALESCE(interest_rate_pa, 0.11) INTO v_rate
  FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved' LIMIT 1;

  -- Piutang RS = invoice yang belum lunas (bukan paid dan bukan partially_paid+shortfall_covered)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_ar_rs
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND NOT (status = 'paid' OR (status = 'partially_paid' AND shortfall_covered_by_bank = TRUE));

  -- Hutang SCF ke Bank
  SELECT COALESCE(SUM(total_payable - paid_amount), 0) INTO v_hutang_scf
  FROM ar_accounts
  WHERE ksm_tenant_id = p_ksm_tenant_id AND status NOT IN ('paid','defaulted');

  -- Persediaan in-transit (estimasi 20% dari PO value)
  SELECT COALESCE(SUM(total_amount * 0.20), 0) INTO v_transit
  FROM ksm_purchase_orders
  WHERE ksm_tenant_id = p_ksm_tenant_id AND status IN ('sent_to_supplier','partially_received');

  -- Bunga shortfall akrual 50% KSM
  SELECT COALESCE(SUM(
    ROUND(shortfall_amount * (v_rate / 365.0) *
      GREATEST(0, CURRENT_DATE - invoice_date) * 0.5, 0)
  ), 0) INTO v_interest_acc
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id AND shortfall_covered_by_bank = TRUE AND shortfall_amount > 0;

  -- Kas estimasi
  SELECT COALESCE(SUM(paid_amount),0), COALESCE(SUM(disbursed_amount),0)
  INTO v_scf_paid, v_scf_disbursed
  FROM ar_accounts WHERE ksm_tenant_id = p_ksm_tenant_id;

  DECLARE
    v_cash     NUMERIC := GREATEST(0, v_scf_paid - (v_scf_disbursed * 0.88)) + 500000000;
    v_fixed    NUMERIC := 150000000;
    v_total_a  NUMERIC := v_cash + v_ar_rs + v_transit + v_fixed;
    v_total_l  NUMERIC := v_hutang_scf + v_interest_acc;
  BEGIN
    RETURN jsonb_build_object(
      'cash',             v_cash,
      'ar_rs',            v_ar_rs,
      'inventory_transit', v_transit,
      'fixed_assets',     v_fixed,
      'hutang_scf',       v_hutang_scf,
      'interest_accrual', v_interest_acc,
      'equity',           v_total_a - v_total_l,
      'total_assets',     v_total_a,
      'total_liabilities', v_total_l
    );
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 4. PAYMENTS & BPJS TRACKING
-- =============================================================================
CREATE OR REPLACE FUNCTION get_ksm_payments(p_ksm_tenant_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_rate     NUMERIC;
  v_invoices JSONB;
BEGIN
  SELECT COALESCE(interest_rate_pa, 0.11) INTO v_rate
  FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved' LIMIT 1;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id',                    i.id,
      'invoice_number',        i.invoice_number,
      'invoice_date',          i.invoice_date,
      'due_date',              i.due_date,
      'total_amount',          i.total_amount,
      'paid_amount',           i.paid_amount,
      'outstanding',           i.outstanding,
      'status',                i.status,
      'bpjs_amount',           i.bpjs_amount,
      'bpjs_received_date',    i.bpjs_received_date,
      'bpjs_expected_date',    i.bpjs_expected_date,
      'shortfall_amount',      i.shortfall_amount,
      'shortfall_covered_by_bank', i.shortfall_covered_by_bank,
      'metadata',              i.metadata,
      'ksm_interest',          CASE
        WHEN i.shortfall_covered_by_bank AND COALESCE(i.shortfall_amount,0) > 0
        THEN ROUND(i.shortfall_amount * (v_rate / 365.0) *
             GREATEST(0, CURRENT_DATE - i.invoice_date) * 0.5, 0)
        ELSE 0
      END
    ) ORDER BY i.due_date
  ) INTO v_invoices
  FROM ksm_invoices i
  WHERE i.ksm_tenant_id = p_ksm_tenant_id
    AND i.status IN ('sent_to_rs','payment_pending','partially_paid','overdue');

  RETURN jsonb_build_object(
    'invoices',        COALESCE(v_invoices, '[]'::JSONB),
    'interest_rate_pa', v_rate
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 5. AR & TAGIHAN
-- =============================================================================
CREATE OR REPLACE FUNCTION get_ksm_ar_data(p_ksm_tenant_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_invoices JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',                    i.id,
      'invoice_number',        i.invoice_number,
      'invoice_date',          i.invoice_date,
      'due_date',              i.due_date,
      'total_amount',          i.total_amount,
      'paid_amount',           i.paid_amount,
      'outstanding',           i.outstanding,
      'status',                i.status,
      'bpjs_amount',           i.bpjs_amount,
      'bpjs_received_date',    i.bpjs_received_date,
      'shortfall_amount',      i.shortfall_amount,
      'shortfall_covered_by_bank', i.shortfall_covered_by_bank,
      'metadata',              i.metadata
    ) ORDER BY i.due_date ASC
  ) INTO v_invoices
  FROM ksm_invoices i
  WHERE i.ksm_tenant_id = p_ksm_tenant_id
  LIMIT 200;

  RETURN jsonb_build_object('invoices', COALESCE(v_invoices, '[]'::JSONB));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 6. REVENUE CYCLE MANAGEMENT
-- =============================================================================
CREATE OR REPLACE FUNCTION get_ksm_rcm(
  p_ksm_tenant_id UUID,
  p_date_from      DATE,
  p_date_to        DATE
)
RETURNS JSONB AS $$
DECLARE
  v_rate           NUMERIC;
  v_revenue        NUMERIC := 0;
  v_cogs           NUMERIC := 0;
  v_scf_interest   NUMERIC := 0;
  v_sf_interest    NUMERIC := 0;
  v_dso            NUMERIC := 0;
  v_fulfilment     NUMERIC := 0;
  v_aging          JSONB;
  v_unpaid         JSONB;
BEGIN
  SELECT COALESCE(interest_rate_pa, 0.11) INTO v_rate
  FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved' LIMIT 1;

  -- Revenue dari invoice yang paid
  SELECT COALESCE(SUM(total_amount - tax_amount), 0) INTO v_revenue
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND (status = 'paid' OR (status = 'partially_paid' AND shortfall_covered_by_bank = TRUE))
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  -- COGS
  SELECT COALESCE(SUM(disbursed_amount),0), COALESCE(SUM(interest_amount),0)
  INTO v_cogs, v_scf_interest
  FROM ar_accounts
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  IF v_cogs = 0 AND v_revenue > 0 THEN
    v_cogs := ROUND(v_revenue * 0.88, 0);
    v_scf_interest := ROUND(v_cogs * (v_rate / 12.0), 0);
  END IF;

  -- Bunga shortfall KSM
  SELECT COALESCE(SUM(
    ROUND(shortfall_amount * (v_rate / 365.0) * GREATEST(0, p_date_to - invoice_date) * 0.5, 0)
  ), 0) INTO v_sf_interest
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND shortfall_covered_by_bank = TRUE AND shortfall_amount > 0
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  -- DSO: avg days dari invoice_date ke paid_date untuk invoice paid dalam periode
  SELECT COALESCE(AVG(paid_date - invoice_date), 0) INTO v_dso
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id AND status = 'paid'
    AND invoice_date BETWEEN p_date_from AND p_date_to AND paid_date IS NOT NULL;

  -- Fulfilment rate
  SELECT CASE WHEN COUNT(*) > 0 THEN
    ROUND(COUNT(*) FILTER (WHERE status = 'completed')::NUMERIC / COUNT(*) * 100, 1)
    ELSE 0 END INTO v_fulfilment
  FROM hospital_notifications WHERE ksm_tenant_id = p_ksm_tenant_id;

  -- AR Aging (piutang RS yang belum lunas)
  SELECT jsonb_build_object(
    'current', COALESCE(SUM(total_amount) FILTER (WHERE due_date >= CURRENT_DATE), 0),
    'd30',     COALESCE(SUM(total_amount) FILTER (WHERE due_date < CURRENT_DATE AND due_date >= CURRENT_DATE - 30), 0),
    'd60',     COALESCE(SUM(total_amount) FILTER (WHERE due_date < CURRENT_DATE - 30 AND due_date >= CURRENT_DATE - 60), 0),
    'd90',     COALESCE(SUM(total_amount) FILTER (WHERE due_date < CURRENT_DATE - 60), 0)
  ) INTO v_aging
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND NOT (status = 'paid' OR (status = 'partially_paid' AND shortfall_covered_by_bank = TRUE));

  DECLARE
    v_gp     NUMERIC := v_revenue - v_cogs;
    v_total_int NUMERIC := v_scf_interest + v_sf_interest;
    v_net    NUMERIC := v_gp - v_total_int;
  BEGIN
    RETURN jsonb_build_object(
      'revenue',          v_revenue,
      'cogs',             v_cogs,
      'gross_profit',     v_gp,
      'gross_margin_pct', CASE WHEN v_revenue > 0 THEN ROUND(v_gp / v_revenue * 100, 2) ELSE 0 END,
      'scf_interest',     v_scf_interest,
      'shortfall_interest_ksm', v_sf_interest,
      'net_profit',       v_net,
      'net_margin_pct',   CASE WHEN v_revenue > 0 THEN ROUND(v_net / v_revenue * 100, 2) ELSE 0 END,
      'dso',              ROUND(v_dso, 1),
      'fulfilment_rate',  v_fulfilment,
      'ar_aging',         COALESCE(v_aging, '{}'::JSONB)
    );
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 7. SCF FACILITIES
-- =============================================================================
CREATE OR REPLACE FUNCTION get_ksm_scf_data(p_ksm_tenant_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_facilities JSONB;
  v_ar_list    JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',                       f.id,
      'facility_number',          f.facility_number,
      'financing_type',           f.financing_type,
      'facility_limit',           f.facility_limit,
      'outstanding',              f.outstanding,
      'available_limit',          f.available_limit,
      'interest_rate_pa',         f.interest_rate_pa,
      'tenor_days',               f.tenor_days,
      'payment_terms',            f.payment_terms,
      'status',                   f.status,
      'facility_start',           f.facility_start,
      'facility_end',             f.facility_end,
      'standing_instruction_active', f.standing_instruction_active
    ) ORDER BY f.facility_start DESC
  ) INTO v_facilities
  FROM scf_facilities f WHERE f.borrower_tenant_id = p_ksm_tenant_id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id',               a.id,
      'ar_number',        a.ar_number,
      'po_number',        a.po_number,
      'invoice_amount',   a.invoice_amount,
      'disbursed_amount', a.disbursed_amount,
      'interest_amount',  a.interest_amount,
      'total_payable',    a.total_payable,
      'paid_amount',      a.paid_amount,
      'outstanding_amount', a.outstanding_amount,
      'disbursement_date', a.disbursement_date,
      'due_date',         a.due_date,
      'status',           a.status
    ) ORDER BY a.due_date ASC
  ) INTO v_ar_list
  FROM ar_accounts a WHERE a.ksm_tenant_id = p_ksm_tenant_id
  LIMIT 50;

  RETURN jsonb_build_object(
    'facilities', COALESCE(v_facilities, '[]'::JSONB),
    'ar_accounts', COALESCE(v_ar_list, '[]'::JSONB)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT EXECUTE ON FUNCTION get_ksm_cashflow(UUID, DATE, DATE)       TO authenticated;
GRANT EXECUTE ON FUNCTION get_ksm_pl(UUID, DATE, DATE)             TO authenticated;
GRANT EXECUTE ON FUNCTION get_ksm_balance_sheet(UUID)              TO authenticated;
GRANT EXECUTE ON FUNCTION get_ksm_payments(UUID)                   TO authenticated;
GRANT EXECUTE ON FUNCTION get_ksm_ar_data(UUID)                    TO authenticated;
GRANT EXECUTE ON FUNCTION get_ksm_rcm(UUID, DATE, DATE)            TO authenticated;
GRANT EXECUTE ON FUNCTION get_ksm_scf_data(UUID)                   TO authenticated;

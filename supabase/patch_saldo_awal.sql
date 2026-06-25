-- Patch v2: fix saldo_awal — hitung net cash flow per bulan lalu dijumlahkan
-- Masalah: bunga shortfall dihitung kumulatif (invoice_date → p_date_from)
-- padahal seharusnya per periode (invoice_date → akhir bulan invoice)

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
BEGIN
  SELECT COALESCE(interest_rate_pa, 0.11) INTO v_rate
  FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved' LIMIT 1;

  -- ── Kas masuk periode ────────────────────────────────────────────────────────
  SELECT
    COALESCE(SUM(bpjs_amount), 0),
    COALESCE(SUM(CASE WHEN shortfall_covered_by_bank THEN shortfall_amount ELSE 0 END), 0)
  INTO v_kas_masuk_bpjs, v_kas_masuk_sf
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND status IN ('paid','partially_paid')
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  -- ── Kas keluar: SCF dari ar_accounts ────────────────────────────────────────
  SELECT COALESCE(SUM(disbursed_amount),0), COALESCE(SUM(interest_amount),0)
  INTO v_scf_principal, v_scf_interest
  FROM ar_accounts
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  IF v_scf_principal = 0 THEN
    SELECT COALESCE(SUM((total_amount / 1.11) * 0.88), 0) INTO v_scf_principal
    FROM ksm_invoices
    WHERE ksm_tenant_id = p_ksm_tenant_id
      AND status IN ('paid','partially_paid')
      AND invoice_date BETWEEN p_date_from AND p_date_to;
    v_scf_interest := ROUND(v_scf_principal * (v_rate / 12.0), 0);
  END IF;

  -- ── Bunga shortfall 50% KSM untuk periode ini ────────────────────────────────
  -- Hari dihitung dari invoice_date → p_date_to (akhir periode ini)
  SELECT COALESCE(SUM(
    ROUND(shortfall_amount * (v_rate / 365.0) *
      GREATEST(0, p_date_to - invoice_date) * 0.5, 0)
  ), 0) INTO v_sf_interest
  FROM ksm_invoices
  WHERE ksm_tenant_id = p_ksm_tenant_id
    AND shortfall_covered_by_bank = TRUE AND shortfall_amount > 0
    AND invoice_date BETWEEN p_date_from AND p_date_to;

  -- ── Saldo awal: net cash flow kumulatif dari semua BULAN sebelumnya ──────────
  -- Bunga shortfall per bulan = invoice di bulan tsb × (akhir bulan - invoice_date)
  -- BUKAN kumulatif invoice_date → p_date_from (itu yang salah sebelumnya)
  WITH monthly_inv AS (
    SELECT
      date_trunc('month', invoice_date)::DATE AS month_start,
      COALESCE(SUM(bpjs_amount),0) +
        COALESCE(SUM(CASE WHEN shortfall_covered_by_bank THEN shortfall_amount ELSE 0 END),0) AS kas_masuk
    FROM ksm_invoices
    WHERE ksm_tenant_id = p_ksm_tenant_id AND status IN ('paid','partially_paid')
      AND invoice_date >= v_data_start AND invoice_date < p_date_from
    GROUP BY 1
  ),
  monthly_ar AS (
    SELECT
      date_trunc('month', invoice_date)::DATE AS month_start,
      COALESCE(SUM(disbursed_amount + interest_amount),0) AS scf_out
    FROM ar_accounts
    WHERE ksm_tenant_id = p_ksm_tenant_id
      AND invoice_date >= v_data_start AND invoice_date < p_date_from
    GROUP BY 1
  ),
  monthly_sf AS (
    -- Bunga shortfall per bulan: hari = invoice_date → akhir bulan invoice itu
    SELECT
      date_trunc('month', invoice_date)::DATE AS month_start,
      COALESCE(SUM(
        ROUND(shortfall_amount * (v_rate / 365.0) *
          GREATEST(0,
            (date_trunc('month', invoice_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE
            - invoice_date
          ) * 0.5, 0)
      ),0) AS sf_interest
    FROM ksm_invoices
    WHERE ksm_tenant_id = p_ksm_tenant_id
      AND shortfall_covered_by_bank = TRUE AND shortfall_amount > 0
      AND invoice_date >= v_data_start AND invoice_date < p_date_from
    GROUP BY 1
  )
  SELECT GREATEST(0, COALESCE(SUM(
    mi.kas_masuk
    -- SCF keluar: dari ar_accounts jika ada, fallback dari invoice
    - CASE WHEN COALESCE(ma.scf_out, 0) > 0 THEN ma.scf_out
           ELSE ROUND(mi.kas_masuk / 1.11 * 0.88 * (1.0 + v_rate / 12.0), 0)
      END
    - COALESCE(ms.sf_interest, 0)
    - mi.kas_masuk * 0.04
  ), 0)) INTO v_saldo_awal
  FROM monthly_inv mi
  LEFT JOIN monthly_ar ma ON ma.month_start = mi.month_start
  LEFT JOIN monthly_sf ms ON ms.month_start = mi.month_start;

  RETURN jsonb_build_object(
    'kas_masuk_bpjs',         v_kas_masuk_bpjs,
    'kas_masuk_shortfall',    v_kas_masuk_sf,
    'scf_principal',          v_scf_principal,
    'scf_interest',           v_scf_interest,
    'shortfall_interest_ksm', v_sf_interest,
    'saldo_awal',             v_saldo_awal,
    'interest_rate_pa',       v_rate
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_ksm_cashflow(UUID, DATE, DATE) TO authenticated;

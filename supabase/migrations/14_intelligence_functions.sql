-- =============================================================================
-- TransLOG-X  |  14_intelligence_functions.sql
-- Fungsi analitik & prediksi berbasis data real
-- Moving average, trend, seasonal, forecasting, risk scoring
-- =============================================================================


-- =============================================================================
-- 1. RPC: Ringkasan KPI Dashboard (real-time dari semua tabel)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_ksm_dashboard_kpi(p_ksm_tenant_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    -- Revenue & Invoice
    'total_invoices', (SELECT COUNT(*) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id),
    'revenue_total', (SELECT COALESCE(SUM(total_amount), 0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id),
    'revenue_this_month', (SELECT COALESCE(SUM(total_amount), 0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND invoice_date >= DATE_TRUNC('month', CURRENT_DATE)),
    'outstanding_from_rs', (SELECT COALESCE(SUM(total_amount - paid_amount), 0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND status NOT IN ('paid')),

    -- PO
    'active_pos', (SELECT COUNT(*) FROM ksm_purchase_orders WHERE ksm_tenant_id = p_ksm_tenant_id AND status IN ('submitted','approved','sent_to_supplier','partially_received')),
    'po_total_value', (SELECT COALESCE(SUM(total_amount), 0) FROM ksm_purchase_orders WHERE ksm_tenant_id = p_ksm_tenant_id AND status NOT IN ('cancelled')),

    -- SCF / Hutang Bank
    'scf_outstanding', (SELECT COALESCE(SUM(outstanding), 0) FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved'),
    'scf_limit', (SELECT COALESCE(SUM(facility_limit), 0) FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved'),
    'hutang_bank', (SELECT COALESCE(SUM(total_payable - paid_amount), 0) FROM ar_accounts WHERE ksm_tenant_id = p_ksm_tenant_id AND status NOT IN ('paid')),
    'bank_to_dist_total', (SELECT COALESCE(SUM(disbursed_amount), 0) FROM ar_accounts WHERE ksm_tenant_id = p_ksm_tenant_id),

    -- Shortfall & Interest
    'total_shortfall', (SELECT COALESCE(SUM(shortfall_amount), 0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND shortfall_covered_by_bank = TRUE),
    'total_daily_interest_ksm', (SELECT COALESCE(SUM(d.ksm_share), 0) FROM daily_interest_accruals d JOIN ksm_invoices i ON i.id = d.invoice_id WHERE i.ksm_tenant_id = p_ksm_tenant_id),

    -- Notifications
    'pending_notifs', (SELECT COUNT(*) FROM hospital_notifications WHERE ksm_tenant_id = p_ksm_tenant_id AND status = 'pending'),
    'pending_rs_approval', (SELECT COUNT(*) FROM hospital_notifications WHERE ksm_tenant_id = p_ksm_tenant_id AND ksm_confirmation_status = 'pending_rs_approval'),

    -- Overdue
    'overdue_invoices', (SELECT COUNT(*) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND due_date < CURRENT_DATE AND status NOT IN ('paid')),
    'overdue_amount', (SELECT COALESCE(SUM(total_amount - paid_amount), 0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND due_date < CURRENT_DATE AND status NOT IN ('paid'))
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 2. RPC: Monthly trend data (6 bulan terakhir)
-- Revenue, COGS, PO count, collection rate
-- =============================================================================

CREATE OR REPLACE FUNCTION get_monthly_trends(p_ksm_tenant_id UUID, p_months INT DEFAULT 6)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB := '[]'::JSONB;
  v_month RECORD;
BEGIN
  FOR v_month IN
    SELECT generate_series(
      DATE_TRUNC('month', CURRENT_DATE) - ((p_months - 1) || ' months')::INTERVAL,
      DATE_TRUNC('month', CURRENT_DATE),
      '1 month'::INTERVAL
    )::DATE AS month_start
  LOOP
    v_result := v_result || jsonb_build_object(
      'month', TO_CHAR(v_month.month_start, 'YYYY-MM'),
      'month_label', TO_CHAR(v_month.month_start, 'Mon YY'),
      'revenue', (
        SELECT COALESCE(SUM(total_amount), 0) FROM ksm_invoices
        WHERE ksm_tenant_id = p_ksm_tenant_id
        AND invoice_date >= v_month.month_start
        AND invoice_date < v_month.month_start + '1 month'::INTERVAL
      ),
      'cogs', (
        SELECT COALESCE(SUM(disbursed_amount), 0) FROM ar_accounts
        WHERE ksm_tenant_id = p_ksm_tenant_id
        AND disbursement_date >= v_month.month_start
        AND disbursement_date < v_month.month_start + '1 month'::INTERVAL
      ),
      'po_count', (
        SELECT COUNT(*) FROM ksm_purchase_orders
        WHERE ksm_tenant_id = p_ksm_tenant_id
        AND po_date >= v_month.month_start
        AND po_date < v_month.month_start + '1 month'::INTERVAL
      ),
      'collected', (
        SELECT COALESCE(SUM(paid_amount), 0) FROM ksm_invoices
        WHERE ksm_tenant_id = p_ksm_tenant_id
        AND invoice_date >= v_month.month_start
        AND invoice_date < v_month.month_start + '1 month'::INTERVAL
      ),
      'notif_count', (
        SELECT COUNT(*) FROM hospital_notifications
        WHERE ksm_tenant_id = p_ksm_tenant_id
        AND notif_date >= v_month.month_start
        AND notif_date < v_month.month_start + '1 month'::INTERVAL
      )
    );
  END LOOP;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 3. RPC: Forecasting — prediksi 3 bulan ke depan
-- Weighted moving average + growth trend
-- =============================================================================

CREATE OR REPLACE FUNCTION forecast_next_months(p_ksm_tenant_id UUID, p_forecast_months INT DEFAULT 3)
RETURNS JSONB AS $$
DECLARE
  v_history NUMERIC[];
  v_wma NUMERIC;
  v_growth NUMERIC;
  v_forecast JSONB := '[]'::JSONB;
  v_base NUMERIC;
  v_i INT;
  v_month DATE;
BEGIN
  -- Ambil revenue 6 bulan terakhir
  SELECT ARRAY_AGG(rev ORDER BY m) INTO v_history
  FROM (
    SELECT DATE_TRUNC('month', invoice_date) AS m,
           COALESCE(SUM(total_amount), 0) AS rev
    FROM ksm_invoices
    WHERE ksm_tenant_id = p_ksm_tenant_id
    AND invoice_date >= DATE_TRUNC('month', CURRENT_DATE) - '5 months'::INTERVAL
    GROUP BY DATE_TRUNC('month', invoice_date)
    ORDER BY m
  ) sub;

  IF v_history IS NULL OR array_length(v_history, 1) < 2 THEN
    -- Tidak cukup data, return estimasi flat
    v_base := COALESCE(v_history[1], 0);
    FOR v_i IN 1..p_forecast_months LOOP
      v_month := DATE_TRUNC('month', CURRENT_DATE) + (v_i || ' months')::INTERVAL;
      v_forecast := v_forecast || jsonb_build_object(
        'month', TO_CHAR(v_month, 'YYYY-MM'),
        'month_label', TO_CHAR(v_month, 'Mon YY'),
        'predicted_revenue', ROUND(v_base, 0),
        'confidence', 'low',
        'method', 'insufficient_data'
      );
    END LOOP;
    RETURN v_forecast;
  END IF;

  -- Weighted Moving Average (bobot terbaru lebih besar)
  v_wma := 0;
  DECLARE
    v_len INT := array_length(v_history, 1);
    v_weight_sum NUMERIC := 0;
  BEGIN
    FOR v_i IN 1..v_len LOOP
      v_wma := v_wma + v_history[v_i] * v_i;
      v_weight_sum := v_weight_sum + v_i;
    END LOOP;
    v_wma := v_wma / NULLIF(v_weight_sum, 0);

    -- Growth rate dari 3 bulan terakhir vs 3 bulan sebelumnya
    IF v_len >= 4 THEN
      DECLARE
        v_recent NUMERIC := (v_history[v_len] + v_history[v_len-1]) / 2.0;
        v_older NUMERIC := (v_history[v_len-2] + v_history[v_len-3]) / 2.0;
      BEGIN
        v_growth := CASE WHEN v_older > 0 THEN (v_recent - v_older) / v_older ELSE 0.05 END;
      END;
    ELSE
      v_growth := 0.05; -- default 5% growth
    END IF;
  END;

  -- Generate forecast
  v_base := v_wma;
  FOR v_i IN 1..p_forecast_months LOOP
    v_month := DATE_TRUNC('month', CURRENT_DATE) + (v_i || ' months')::INTERVAL;
    v_base := v_base * (1 + v_growth);
    v_forecast := v_forecast || jsonb_build_object(
      'month', TO_CHAR(v_month, 'YYYY-MM'),
      'month_label', TO_CHAR(v_month, 'Mon YY'),
      'predicted_revenue', ROUND(v_base, 0),
      'growth_rate', ROUND(v_growth * 100, 1),
      'confidence', CASE
        WHEN array_length(v_history, 1) >= 6 THEN 'high'
        WHEN array_length(v_history, 1) >= 3 THEN 'medium'
        ELSE 'low'
      END,
      'method', 'weighted_moving_average'
    );
  END LOOP;

  RETURN v_forecast;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 4. RPC: Risk scoring — skor risiko per RS mitra
-- Berdasarkan: payment history, overdue frequency, shortfall history
-- =============================================================================

CREATE OR REPLACE FUNCTION get_rs_risk_scores(p_ksm_tenant_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB := '[]'::JSONB;
  v_rs RECORD;
BEGIN
  FOR v_rs IN
    SELECT DISTINCT rs_tenant_id,
      metadata->>'rs_name' AS rs_name
    FROM ksm_invoices
    WHERE ksm_tenant_id = p_ksm_tenant_id
    GROUP BY rs_tenant_id, metadata->>'rs_name'
  LOOP
    v_result := v_result || (
      SELECT jsonb_build_object(
        'rs_tenant_id', v_rs.rs_tenant_id,
        'rs_name', COALESCE(v_rs.rs_name, v_rs.rs_tenant_id::TEXT),
        'total_invoices', COUNT(*),
        'total_value', COALESCE(SUM(total_amount), 0),
        'paid_count', COUNT(*) FILTER (WHERE status = 'paid'),
        'overdue_count', COUNT(*) FILTER (WHERE due_date < CURRENT_DATE AND status NOT IN ('paid')),
        'overdue_amount', COALESCE(SUM(total_amount - paid_amount) FILTER (WHERE due_date < CURRENT_DATE AND status NOT IN ('paid')), 0),
        'shortfall_count', COUNT(*) FILTER (WHERE shortfall_covered_by_bank = TRUE),
        'shortfall_total', COALESCE(SUM(shortfall_amount) FILTER (WHERE shortfall_covered_by_bank = TRUE), 0),
        'avg_payment_days', ROUND(AVG(
          CASE WHEN status = 'paid' AND bpjs_received_date IS NOT NULL
          THEN bpjs_received_date - invoice_date
          ELSE NULL END
        ), 0),
        'collection_rate', CASE WHEN SUM(total_amount) > 0
          THEN ROUND(SUM(paid_amount) / SUM(total_amount) * 100, 1)
          ELSE 0 END,
        'risk_score', CASE
          WHEN COUNT(*) FILTER (WHERE due_date < CURRENT_DATE AND status NOT IN ('paid')) > 2 THEN 'HIGH'
          WHEN COUNT(*) FILTER (WHERE shortfall_covered_by_bank = TRUE) > 0 THEN 'MEDIUM'
          WHEN COUNT(*) FILTER (WHERE due_date < CURRENT_DATE AND status NOT IN ('paid')) > 0 THEN 'MEDIUM'
          ELSE 'LOW'
        END
      )
      FROM ksm_invoices
      WHERE ksm_tenant_id = p_ksm_tenant_id AND rs_tenant_id = v_rs.rs_tenant_id
    );
  END LOOP;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 5. RPC: Supply demand analysis — item yang paling banyak diminta
-- =============================================================================

CREATE OR REPLACE FUNCTION get_demand_analysis(p_ksm_tenant_id UUID)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT COALESCE(jsonb_agg(item ORDER BY total_requested DESC), '[]'::JSONB)
    FROM (
      SELECT jsonb_build_object(
        'kfa_code', l.kfa_code,
        'item_name', l.item_name,
        'total_requested', SUM(l.requested_qty),
        'total_ordered', COALESCE(SUM(pl.ordered_qty), 0),
        'total_received', COALESCE(SUM(pl.received_qty), 0),
        'fulfillment_rate', CASE WHEN SUM(l.requested_qty) > 0
          THEN ROUND(COALESCE(SUM(pl.ordered_qty), 0)::NUMERIC / SUM(l.requested_qty) * 100, 1)
          ELSE 0 END,
        'notif_count', COUNT(DISTINCT l.notification_id),
        'avg_requested', ROUND(AVG(l.requested_qty), 0)
      ) AS item
      FROM hospital_notification_lines l
      JOIN hospital_notifications n ON n.id = l.notification_id
      LEFT JOIN ksm_po_lines pl ON pl.kfa_code = l.kfa_code
      WHERE n.ksm_tenant_id = p_ksm_tenant_id
      GROUP BY l.kfa_code, l.item_name
      ORDER BY SUM(l.requested_qty) DESC
      LIMIT 20
    ) sub
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT EXECUTE ON FUNCTION get_ksm_dashboard_kpi(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_monthly_trends(UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION forecast_next_months(UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_rs_risk_scores(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_demand_analysis(UUID) TO authenticated;

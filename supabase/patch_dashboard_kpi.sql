-- Fix: total_daily_interest_ksm — hitung dari ksm_invoices langsung (daily_interest_accruals kosong)
CREATE OR REPLACE FUNCTION get_ksm_dashboard_kpi(p_ksm_tenant_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_rate   NUMERIC;
BEGIN
  SELECT COALESCE(interest_rate_pa, 0.11) INTO v_rate
  FROM scf_facilities
  WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved'
  LIMIT 1;

  SELECT jsonb_build_object(
    'total_invoices',        (SELECT COUNT(*) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id),
    'revenue_total',         (SELECT COALESCE(SUM(total_amount),0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id),
    'revenue_this_month',    (SELECT COALESCE(SUM(total_amount),0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND invoice_date >= DATE_TRUNC('month', CURRENT_DATE)),
    'outstanding_from_rs',   (SELECT COALESCE(SUM(total_amount - paid_amount),0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND status NOT IN ('paid')),
    'active_pos',            (SELECT COUNT(*) FROM ksm_purchase_orders WHERE ksm_tenant_id = p_ksm_tenant_id AND status IN ('submitted','approved','sent_to_supplier','partially_received')),
    'po_total_value',        (SELECT COALESCE(SUM(total_amount),0) FROM ksm_purchase_orders WHERE ksm_tenant_id = p_ksm_tenant_id AND status NOT IN ('cancelled')),
    'scf_outstanding',       (SELECT COALESCE(SUM(outstanding),0) FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved'),
    'scf_limit',             (SELECT COALESCE(SUM(facility_limit),0) FROM scf_facilities WHERE borrower_tenant_id = p_ksm_tenant_id AND status = 'approved'),
    'hutang_bank',           (SELECT COALESCE(SUM(total_payable - paid_amount),0) FROM ar_accounts WHERE ksm_tenant_id = p_ksm_tenant_id AND status NOT IN ('paid')),
    'bank_to_dist_total',    (SELECT COALESCE(SUM(disbursed_amount),0) FROM ar_accounts WHERE ksm_tenant_id = p_ksm_tenant_id),
    'total_shortfall',       (SELECT COALESCE(SUM(shortfall_amount),0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND shortfall_covered_by_bank = TRUE),

    -- Hitung bunga shortfall KSM 50% secara matematika (daily_interest_accruals kosong)
    'total_daily_interest_ksm', (
      SELECT COALESCE(SUM(
        ROUND(i.shortfall_amount * (v_rate / 365.0) *
          GREATEST(0, CURRENT_DATE - i.invoice_date) * 0.5, 0)
      ), 0)
      FROM ksm_invoices i
      WHERE i.ksm_tenant_id = p_ksm_tenant_id
        AND i.shortfall_covered_by_bank = TRUE
        AND i.shortfall_amount > 0
    ),

    'pending_notifs',        (SELECT COUNT(*) FROM hospital_notifications WHERE ksm_tenant_id = p_ksm_tenant_id AND status = 'pending'),
    'pending_rs_approval',   (SELECT COUNT(*) FROM hospital_notifications WHERE ksm_tenant_id = p_ksm_tenant_id AND ksm_confirmation_status = 'pending_rs_approval'),
    'overdue_invoices',      (SELECT COUNT(*) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND due_date < CURRENT_DATE AND status NOT IN ('paid')),
    'overdue_amount',        (SELECT COALESCE(SUM(total_amount - paid_amount),0) FROM ksm_invoices WHERE ksm_tenant_id = p_ksm_tenant_id AND due_date < CURRENT_DATE AND status NOT IN ('paid'))
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_ksm_dashboard_kpi(UUID) TO authenticated;

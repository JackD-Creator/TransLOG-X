-- =============================================================================
-- TransLOG-X  |  12_backend_functions.sql
-- Backend business logic: DB functions, triggers, status validation
-- Semua logic bisnis di server (PostgreSQL), BUKAN di browser
-- =============================================================================

-- =============================================================================
-- 1. NOTIFIKASI: Validasi status transition
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_validate_notif_status()
RETURNS TRIGGER AS $$
DECLARE
  valid_transitions JSONB := '{
    "pending":      ["acknowledged", "cancelled"],
    "acknowledged": ["po_created", "cancelled"],
    "po_created":   ["completed", "cancelled"],
    "completed":    [],
    "cancelled":    []
  }'::JSONB;
  allowed TEXT[];
BEGIN
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;

  SELECT array_agg(value #>> '{}')
    INTO allowed
    FROM jsonb_array_elements(valid_transitions -> OLD.status);

  IF NEW.status != ALL(COALESCE(allowed, ARRAY[]::TEXT[])) THEN
    RAISE EXCEPTION 'Transisi status notifikasi tidak valid: % → %', OLD.status, NEW.status;
  END IF;

  IF NEW.status = 'acknowledged' AND OLD.status = 'pending' THEN
    NEW.acknowledged_at := NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notif_status_validate ON hospital_notifications;
CREATE TRIGGER trg_notif_status_validate
  BEFORE UPDATE OF status ON hospital_notifications
  FOR EACH ROW EXECUTE FUNCTION fn_validate_notif_status();


-- =============================================================================
-- 2. PO: Validasi status transition
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_validate_po_status()
RETURNS TRIGGER AS $$
DECLARE
  valid_transitions JSONB := '{
    "draft":              ["submitted", "cancelled"],
    "submitted":          ["approved", "cancelled"],
    "approved":           ["sent_to_supplier", "submitted", "cancelled"],
    "sent_to_supplier":   ["partially_received", "fully_received"],
    "partially_received": ["fully_received"],
    "fully_received":     ["closed"],
    "cancelled":          [],
    "closed":             []
  }'::JSONB;
  allowed TEXT[];
BEGIN
  IF OLD.status::TEXT = NEW.status::TEXT THEN RETURN NEW; END IF;

  SELECT array_agg(value #>> '{}')
    INTO allowed
    FROM jsonb_array_elements(valid_transitions -> OLD.status::TEXT);

  IF NEW.status::TEXT != ALL(COALESCE(allowed, ARRAY[]::TEXT[])) THEN
    RAISE EXCEPTION 'Transisi status PO tidak valid: % → %', OLD.status, NEW.status;
  END IF;

  -- Auto-set timestamps
  IF NEW.status = 'submitted' THEN NEW.submitted_at := NOW(); END IF;
  IF NEW.status = 'approved'  THEN NEW.approved_at  := NOW(); END IF;
  IF NEW.status = 'sent_to_supplier' THEN NEW.sent_at := NOW(); END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_po_status_validate ON ksm_purchase_orders;
CREATE TRIGGER trg_po_status_validate
  BEFORE UPDATE OF status ON ksm_purchase_orders
  FOR EACH ROW EXECUTE FUNCTION fn_validate_po_status();


-- =============================================================================
-- 3. RPC: Review notifikasi & cek ketersediaan supplier
-- Frontend panggil: supabase.rpc('notif_review_and_check_supplier', {p_notif_id})
-- =============================================================================

CREATE OR REPLACE FUNCTION notif_review_and_check_supplier(p_notif_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_notif  hospital_notifications%ROWTYPE;
  v_items  JSONB;
  v_avail  JSONB := '[]'::JSONB;
  v_line   RECORD;
  v_sup    RECORD;
BEGIN
  SELECT * INTO v_notif FROM hospital_notifications WHERE id = p_notif_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Notifikasi tidak ditemukan'; END IF;
  IF v_notif.status != 'pending' THEN
    RAISE EXCEPTION 'Notifikasi harus berstatus pending, saat ini: %', v_notif.status;
  END IF;

  -- Cek ketersediaan setiap item di supplier_catalog_items
  FOR v_line IN
    SELECT * FROM hospital_notification_lines WHERE notification_id = p_notif_id
  LOOP
    SELECT kfa_code, sell_price, stock_available, lead_time_days,
           metadata->>'distributor_name' AS dist_name
      INTO v_sup
      FROM supplier_catalog_items
      WHERE kfa_code = v_line.kfa_code AND is_available = true
      ORDER BY sell_price ASC
      LIMIT 1;

    v_avail := v_avail || jsonb_build_object(
      'kfa_code', v_line.kfa_code,
      'item_name', v_line.item_name,
      'requested_qty', v_line.requested_qty,
      'available', v_sup.kfa_code IS NOT NULL,
      'stock', COALESCE(v_sup.stock_available, 0),
      'sell_price', COALESCE(v_sup.sell_price, 0),
      'lead_time', COALESCE(v_sup.lead_time_days, 0),
      'distributor', COALESCE(v_sup.dist_name, 'N/A')
    );
  END LOOP;

  -- Update status → acknowledged + simpan hasil pengecekan
  UPDATE hospital_notifications SET
    status = 'acknowledged',
    metadata = v_notif.metadata
      || jsonb_build_object('supplier_check', 'checking', 'supplier_availability', v_avail)
  WHERE id = p_notif_id;

  RETURN jsonb_build_object(
    'success', true,
    'notif_id', p_notif_id,
    'items_checked', jsonb_array_length(v_avail),
    'availability', v_avail
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 4. RPC: Supplier konfirmasi ketersediaan
-- Frontend panggil: supabase.rpc('notif_supplier_confirm', {p_notif_id})
-- =============================================================================

CREATE OR REPLACE FUNCTION notif_supplier_confirm(p_notif_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_notif hospital_notifications%ROWTYPE;
BEGIN
  SELECT * INTO v_notif FROM hospital_notifications WHERE id = p_notif_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Notifikasi tidak ditemukan'; END IF;
  IF v_notif.status != 'acknowledged' THEN
    RAISE EXCEPTION 'Status harus acknowledged, saat ini: %', v_notif.status;
  END IF;
  IF v_notif.metadata->>'supplier_check' != 'checking' THEN
    RAISE EXCEPTION 'Supplier check belum dimulai';
  END IF;

  UPDATE hospital_notifications SET
    metadata = v_notif.metadata
      || jsonb_build_object('supplier_check', 'confirmed', 'supplier_confirmed_at', NOW()::TEXT)
  WHERE id = p_notif_id;

  RETURN jsonb_build_object('success', true, 'notif_id', p_notif_id, 'supplier_status', 'confirmed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 5. RPC: Buat PO otomatis dari notifikasi
-- Satu transaksi: buat PO header + lines + update notifikasi
-- Frontend panggil: supabase.rpc('create_po_from_notification', {p_notif_id, p_supplier_tenant_id})
-- =============================================================================

CREATE OR REPLACE FUNCTION create_po_from_notification(
  p_notif_id UUID,
  p_supplier_tenant_id UUID DEFAULT '8187892c-8d84-43b2-a39c-1e171d301297'
)
RETURNS JSONB AS $$
DECLARE
  v_notif     hospital_notifications%ROWTYPE;
  v_po_id     UUID;
  v_po_number TEXT;
  v_subtotal  NUMERIC(15,2) := 0;
  v_tax       NUMERIC(15,2);
  v_total     NUMERIC(15,2);
  v_line      RECORD;
  v_price     NUMERIC(15,2);
  v_line_total NUMERIC(15,2);
  v_dist_name TEXT;
  v_rs_name   TEXT;
  v_rs_addr   TEXT;
  v_line_count INT := 0;
BEGIN
  -- Validasi notifikasi
  SELECT * INTO v_notif FROM hospital_notifications WHERE id = p_notif_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Notifikasi tidak ditemukan'; END IF;
  IF v_notif.status != 'acknowledged' THEN
    RAISE EXCEPTION 'Notifikasi harus acknowledged sebelum buat PO, saat ini: %', v_notif.status;
  END IF;
  IF COALESCE(v_notif.metadata->>'supplier_check', '') != 'confirmed' THEN
    RAISE EXCEPTION 'Supplier belum konfirmasi ketersediaan';
  END IF;

  -- Generate PO number
  v_po_number := 'KSM-PO-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(
    (SELECT COALESCE(MAX(CAST(RIGHT(po_number, 6) AS INT)), 0) + 1
     FROM ksm_purchase_orders WHERE po_number LIKE 'KSM-PO-%')::TEXT, 6, '0');

  -- Ambil info RS & distributor dari metadata
  v_rs_name  := COALESCE(v_notif.metadata->>'rs_name', 'RS Mitra');
  v_rs_addr  := COALESCE(v_notif.metadata->>'rs_address', '');

  SELECT COALESCE(metadata->>'distributor_name', 'Distributor')
    INTO v_dist_name
    FROM supplier_catalog_items
    WHERE tenant_id = p_supplier_tenant_id
    LIMIT 1;

  -- Buat PO header
  INSERT INTO ksm_purchase_orders (
    ksm_tenant_id, supplier_tenant_id, rs_tenant_id, notification_id,
    po_number, po_date, expected_delivery, status, payment_terms,
    subtotal, tax_amount, total_amount, metadata
  ) VALUES (
    v_notif.ksm_tenant_id, p_supplier_tenant_id, v_notif.rs_tenant_id, p_notif_id,
    v_po_number, CURRENT_DATE, CURRENT_DATE + 5, 'submitted', 'net_30',
    0, 0, 0,
    jsonb_build_object(
      'rs_name', v_rs_name,
      'rs_address', v_rs_addr,
      'supplier_name', v_dist_name,
      'auto_from_notif', v_notif.notif_number
    )
  ) RETURNING id INTO v_po_id;

  -- Buat PO lines dari notification lines
  FOR v_line IN
    SELECT * FROM hospital_notification_lines WHERE notification_id = p_notif_id
  LOOP
    -- Ambil harga dari supplier catalog, fallback ke KFA
    SELECT COALESCE(s.sell_price, k.fix_price, 10000)
      INTO v_price
      FROM hospital_notification_lines hnl
      LEFT JOIN supplier_catalog_items s ON s.kfa_code = v_line.kfa_code AND s.tenant_id = p_supplier_tenant_id
      LEFT JOIN kfa_drugs k ON k.kfa_code = v_line.kfa_code
      WHERE hnl.id = v_line.id
      LIMIT 1;

    v_line_total := v_price * v_line.requested_qty;
    v_subtotal := v_subtotal + v_line_total;

    INSERT INTO ksm_po_lines (
      po_id, kfa_code, item_name, catalog_type, uom,
      ordered_qty, unit_price, line_total
    ) VALUES (
      v_po_id, v_line.kfa_code, v_line.item_name, v_line.catalog_type, v_line.uom,
      v_line.requested_qty, v_price, v_line_total
    );

    v_line_count := v_line_count + 1;
  END LOOP;

  -- Update PO totals
  v_tax   := ROUND(v_subtotal * 0.11, 2);
  v_total := v_subtotal + v_tax;

  UPDATE ksm_purchase_orders SET
    subtotal     = v_subtotal,
    tax_amount   = v_tax,
    total_amount = v_total,
    submitted_at = NOW()
  WHERE id = v_po_id;

  -- Update notifikasi → po_created
  UPDATE hospital_notifications SET
    status = 'po_created',
    metadata = v_notif.metadata || jsonb_build_object(
      'po_number', v_po_number,
      'po_id', v_po_id::TEXT,
      'po_created_at', NOW()::TEXT
    )
  WHERE id = p_notif_id;

  RETURN jsonb_build_object(
    'success', true,
    'po_id', v_po_id,
    'po_number', v_po_number,
    'line_count', v_line_count,
    'subtotal', v_subtotal,
    'tax', v_tax,
    'total', v_total
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 6. RPC: RS konfirmasi penerimaan barang
-- Bukan KSM yang terima, RS yang terima lalu info masuk ke KSM
-- Frontend panggil: supabase.rpc('rs_confirm_receipt', {p_po_id, p_received_items})
-- p_received_items: [{"line_id": "...", "received_qty": 100}, ...]
-- =============================================================================

CREATE OR REPLACE FUNCTION rs_confirm_receipt(
  p_po_id UUID,
  p_received_items JSONB
)
RETURNS JSONB AS $$
DECLARE
  v_po     ksm_purchase_orders%ROWTYPE;
  v_item   JSONB;
  v_all_full BOOLEAN := TRUE;
  v_any_received BOOLEAN := FALSE;
  v_line_id UUID;
  v_qty    INT;
  v_ordered INT;
BEGIN
  SELECT * INTO v_po FROM ksm_purchase_orders WHERE id = p_po_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'PO tidak ditemukan'; END IF;
  IF v_po.status NOT IN ('sent_to_supplier', 'partially_received') THEN
    RAISE EXCEPTION 'PO harus dalam status pengiriman, saat ini: %', v_po.status;
  END IF;

  -- Update received_qty per line
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_received_items)
  LOOP
    v_line_id := (v_item->>'line_id')::UUID;
    v_qty     := (v_item->>'received_qty')::INT;

    SELECT ordered_qty INTO v_ordered FROM ksm_po_lines WHERE id = v_line_id AND po_id = p_po_id;
    IF NOT FOUND THEN CONTINUE; END IF;

    IF v_qty > v_ordered THEN
      RAISE EXCEPTION 'Qty terima (%) melebihi qty pesan (%) untuk line %', v_qty, v_ordered, v_line_id;
    END IF;

    UPDATE ksm_po_lines SET received_qty = v_qty WHERE id = v_line_id;

    IF v_qty > 0 THEN v_any_received := TRUE; END IF;
    IF v_qty < v_ordered THEN v_all_full := FALSE; END IF;
  END LOOP;

  -- Update PO status
  IF v_all_full THEN
    UPDATE ksm_purchase_orders SET status = 'fully_received',
      metadata = v_po.metadata || jsonb_build_object('rs_received_at', NOW()::TEXT, 'rs_receipt_status', 'complete')
    WHERE id = p_po_id;
  ELSIF v_any_received THEN
    UPDATE ksm_purchase_orders SET status = 'partially_received',
      metadata = v_po.metadata || jsonb_build_object('rs_partial_received_at', NOW()::TEXT, 'rs_receipt_status', 'partial')
    WHERE id = p_po_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'po_id', p_po_id,
    'status', CASE WHEN v_all_full THEN 'fully_received' WHEN v_any_received THEN 'partially_received' ELSE v_po.status::TEXT END,
    'all_received', v_all_full
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 7. RPC: Supplier konfirmasi PO dengan detail (qty, harga, jadwal kirim)
-- Supplier bisa adjust harga/qty, KSM harus review
-- Frontend panggil: supabase.rpc('supplier_confirm_po', {p_po_id, p_confirmation})
-- p_confirmation: {"tracking_number": "...", "courier": "...", "estimated_arrival": "2026-07-01", "line_adjustments": [...]}
-- =============================================================================

CREATE OR REPLACE FUNCTION supplier_confirm_po(
  p_po_id UUID,
  p_confirmation JSONB
)
RETURNS JSONB AS $$
DECLARE
  v_po ksm_purchase_orders%ROWTYPE;
  v_adj JSONB;
  v_line_id UUID;
BEGIN
  SELECT * INTO v_po FROM ksm_purchase_orders WHERE id = p_po_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'PO tidak ditemukan'; END IF;
  IF v_po.status != 'submitted' THEN
    RAISE EXCEPTION 'PO harus berstatus submitted untuk dikonfirmasi supplier, saat ini: %', v_po.status;
  END IF;

  -- Simpan info konfirmasi supplier ke metadata
  UPDATE ksm_purchase_orders SET
    status = 'approved',
    approved_at = NOW(),
    expected_delivery = COALESCE((p_confirmation->>'estimated_arrival')::DATE, v_po.expected_delivery),
    metadata = v_po.metadata || jsonb_build_object(
      'tracking_number', COALESCE(p_confirmation->>'tracking_number', ''),
      'courier', COALESCE(p_confirmation->>'courier', ''),
      'supplier_confirmed_at', NOW()::TEXT,
      'supplier_notes', COALESCE(p_confirmation->>'notes', ''),
      'supplier_confirmation', p_confirmation,
      'needs_ksm_review', TRUE
    )
  WHERE id = p_po_id;

  -- Apply line adjustments jika ada
  IF p_confirmation ? 'line_adjustments' THEN
    FOR v_adj IN SELECT * FROM jsonb_array_elements(p_confirmation->'line_adjustments')
    LOOP
      v_line_id := (v_adj->>'line_id')::UUID;
      UPDATE ksm_po_lines SET
        unit_price = COALESCE((v_adj->>'adjusted_price')::NUMERIC, unit_price),
        ordered_qty = COALESCE((v_adj->>'adjusted_qty')::INT, ordered_qty),
        line_total = COALESCE((v_adj->>'adjusted_price')::NUMERIC, unit_price) *
                     COALESCE((v_adj->>'adjusted_qty')::INT, ordered_qty),
        notes = COALESCE(v_adj->>'note', notes)
      WHERE id = v_line_id AND po_id = p_po_id;
    END LOOP;

    -- Recalculate totals
    UPDATE ksm_purchase_orders SET
      subtotal     = (SELECT COALESCE(SUM(line_total), 0) FROM ksm_po_lines WHERE po_id = p_po_id),
      tax_amount   = (SELECT ROUND(COALESCE(SUM(line_total), 0) * 0.11, 2) FROM ksm_po_lines WHERE po_id = p_po_id),
      total_amount = (SELECT ROUND(COALESCE(SUM(line_total), 0) * 1.11, 2) FROM ksm_po_lines WHERE po_id = p_po_id)
    WHERE id = p_po_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'po_id', p_po_id,
    'status', 'approved',
    'needs_ksm_review', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 8. RPC: KSM kirim koreksi ke supplier (tolak konfirmasi, minta revisi)
-- Frontend panggil: supabase.rpc('ksm_request_po_correction', {p_po_id, p_reason})
-- =============================================================================

CREATE OR REPLACE FUNCTION ksm_request_po_correction(
  p_po_id UUID,
  p_reason TEXT DEFAULT ''
)
RETURNS JSONB AS $$
DECLARE
  v_po ksm_purchase_orders%ROWTYPE;
BEGIN
  SELECT * INTO v_po FROM ksm_purchase_orders WHERE id = p_po_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'PO tidak ditemukan'; END IF;
  IF v_po.status != 'approved' THEN
    RAISE EXCEPTION 'PO harus berstatus approved untuk dikoreksi, saat ini: %', v_po.status;
  END IF;

  -- Kembalikan ke submitted agar supplier bisa revisi
  UPDATE ksm_purchase_orders SET
    status = 'submitted',
    approved_at = NULL,
    metadata = v_po.metadata || jsonb_build_object(
      'correction_requested', TRUE,
      'correction_reason', p_reason,
      'correction_at', NOW()::TEXT,
      'needs_ksm_review', FALSE
    )
  WHERE id = p_po_id;

  RETURN jsonb_build_object('success', true, 'po_id', p_po_id, 'status', 'submitted', 'correction_sent', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 9. RPC: KSM approve PO final → info otomatis ke RS
-- Frontend panggil: supabase.rpc('ksm_approve_po', {p_po_id})
-- =============================================================================

CREATE OR REPLACE FUNCTION ksm_approve_po(p_po_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_po    ksm_purchase_orders%ROWTYPE;
  v_lines JSONB;
BEGIN
  SELECT * INTO v_po FROM ksm_purchase_orders WHERE id = p_po_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'PO tidak ditemukan'; END IF;
  IF v_po.status != 'approved' THEN
    RAISE EXCEPTION 'PO harus berstatus approved, saat ini: %', v_po.status;
  END IF;

  -- Kumpulkan info item untuk dikirim ke RS
  SELECT jsonb_agg(jsonb_build_object(
    'item_name', item_name,
    'kfa_code', kfa_code,
    'qty', ordered_qty,
    'unit_price', unit_price,
    'total', line_total,
    'uom', uom
  )) INTO v_lines
  FROM ksm_po_lines WHERE po_id = p_po_id;

  -- Update PO → sent_to_supplier + simpan info yang dikirim ke RS
  UPDATE ksm_purchase_orders SET
    status = 'sent_to_supplier',
    sent_at = NOW(),
    metadata = v_po.metadata || jsonb_build_object(
      'needs_ksm_review', FALSE,
      'ksm_approved_at', NOW()::TEXT,
      'rs_notification_sent', TRUE,
      'rs_notification_at', NOW()::TEXT,
      'rs_delivery_info', jsonb_build_object(
        'po_number', v_po.po_number,
        'supplier', v_po.metadata->>'supplier_name',
        'items', v_lines,
        'estimated_arrival', v_po.expected_delivery::TEXT,
        'tracking_number', COALESCE(v_po.metadata->>'tracking_number', ''),
        'courier', COALESCE(v_po.metadata->>'courier', ''),
        'total_amount', v_po.total_amount
      )
    )
  WHERE id = p_po_id;

  -- Update notifikasi asal (jika ada) → completed
  IF v_po.notification_id IS NOT NULL THEN
    UPDATE hospital_notifications SET
      status = 'completed',
      metadata = metadata || jsonb_build_object('completed_at', NOW()::TEXT, 'completed_by_po', v_po.po_number)
    WHERE id = v_po.notification_id AND status = 'po_created';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'po_id', p_po_id,
    'po_number', v_po.po_number,
    'status', 'sent_to_supplier',
    'rs_notified', true,
    'items_count', jsonb_array_length(COALESCE(v_lines, '[]'::JSONB)),
    'total_amount', v_po.total_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 10. TRIGGER: Auto-recalculate PO totals saat lines berubah
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_recalc_po_totals()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE ksm_purchase_orders SET
    subtotal     = sub.s,
    tax_amount   = ROUND(sub.s * 0.11, 2),
    total_amount = ROUND(sub.s * 1.11, 2)
  FROM (
    SELECT COALESCE(SUM(line_total), 0) AS s
    FROM ksm_po_lines WHERE po_id = COALESCE(NEW.po_id, OLD.po_id)
  ) sub
  WHERE id = COALESCE(NEW.po_id, OLD.po_id);

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_po_lines_recalc ON ksm_po_lines;
CREATE TRIGGER trg_po_lines_recalc
  AFTER INSERT OR UPDATE OF unit_price, ordered_qty, line_total OR DELETE
  ON ksm_po_lines
  FOR EACH ROW EXECUTE FUNCTION fn_recalc_po_totals();


-- =============================================================================
-- 11. TRIGGER: Auto-set line_total = unit_price × ordered_qty
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_calc_line_total()
RETURNS TRIGGER AS $$
BEGIN
  NEW.line_total := NEW.unit_price * NEW.ordered_qty;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_po_line_calc ON ksm_po_lines;
CREATE TRIGGER trg_po_line_calc
  BEFORE INSERT OR UPDATE OF unit_price, ordered_qty
  ON ksm_po_lines
  FOR EACH ROW EXECUTE FUNCTION fn_calc_line_total();


-- =============================================================================
-- GRANT EXECUTE ke authenticated users (RLS tetap berlaku di dalam function)
-- =============================================================================

GRANT EXECUTE ON FUNCTION notif_review_and_check_supplier(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION notif_supplier_confirm(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_po_from_notification(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rs_confirm_receipt(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION supplier_confirm_po(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION ksm_request_po_correction(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION ksm_approve_po(UUID) TO authenticated;

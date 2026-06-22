-- =============================================================================
-- TransLOG-X  |  04_m3_order.sql
-- M3: Order Management — GRN, delivery orders, returns
-- =============================================================================

-- =============================================================================
-- GOODS RECEIPT NOTES (GRN)  — Penerimaan barang dari supplier
-- =============================================================================
CREATE TABLE goods_receipts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  po_id           UUID NOT NULL REFERENCES purchase_orders(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
  supplier_id     UUID NOT NULL REFERENCES suppliers(id),

  grn_number      TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft','received','qc_pending','qc_passed','qc_failed','partial','completed','returned')),

  supplier_do_no  TEXT,           -- nomor DO dari supplier
  supplier_inv_no TEXT,           -- nomor invoice dari supplier

  received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  received_by     UUID NOT NULL REFERENCES profiles(id),
  qc_checked_by   UUID REFERENCES profiles(id),
  qc_checked_at   TIMESTAMPTZ,
  qc_notes        TEXT,

  notes           TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}',

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, grn_number)
);

CREATE TABLE grn_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  grn_id          UUID NOT NULL REFERENCES goods_receipts(id) ON DELETE CASCADE,
  po_line_id      UUID REFERENCES po_lines(id),
  product_id      UUID NOT NULL REFERENCES products(id),

  qty_ordered     NUMERIC(12, 4) NOT NULL,
  qty_received    NUMERIC(12, 4) NOT NULL,
  qty_accepted    NUMERIC(12, 4),     -- setelah QC
  qty_rejected    NUMERIC(12, 4),
  uom             TEXT NOT NULL,

  lot_number      TEXT NOT NULL,
  batch_number    TEXT,
  manufactured_at DATE,
  expired_at      DATE NOT NULL,

  unit_price      NUMERIC(15, 4),
  line_total      NUMERIC(18, 2),

  qc_status       TEXT DEFAULT 'pending'
                  CHECK (qc_status IN ('pending','passed','failed','conditional')),
  qc_notes        TEXT,
  reject_reason   TEXT,

  -- Auto-creates stock_lot entry on QC pass
  lot_id          UUID REFERENCES stock_lots(id),
  bin_id          UUID REFERENCES warehouse_bins(id),

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_grn_tenant    ON goods_receipts(tenant_id);
CREATE INDEX idx_grn_po        ON goods_receipts(po_id);
CREATE INDEX idx_grn_status    ON goods_receipts(tenant_id, status);
CREATE INDEX idx_grn_lines_grn ON grn_lines(grn_id);
CREATE INDEX idx_grn_lines_product ON grn_lines(product_id);

CREATE TRIGGER trg_grn_updated_at
  BEFORE UPDATE ON goods_receipts
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- Back-patch FK on stock_lots
ALTER TABLE stock_lots
  ADD CONSTRAINT fk_lots_grn FOREIGN KEY (grn_id) REFERENCES goods_receipts(id);
ALTER TABLE stock_lots
  ADD CONSTRAINT fk_lots_po  FOREIGN KEY (po_id)  REFERENCES purchase_orders(id);

-- =============================================================================
-- TRIGGER: update po_lines.qty_received after GRN line saved
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_grn_update_po_line()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.po_line_id IS NOT NULL AND NEW.qty_accepted IS NOT NULL THEN
    UPDATE po_lines SET
      qty_received = COALESCE(qty_received, 0) + NEW.qty_accepted
    WHERE id = NEW.po_line_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_grn_line_update_po
  AFTER INSERT OR UPDATE OF qty_accepted ON grn_lines
  FOR EACH ROW EXECUTE FUNCTION fn_grn_update_po_line();

-- =============================================================================
-- DELIVERY ORDERS (DO)  — Surat Jalan pengiriman ke internal (antar gudang / unit)
-- =============================================================================
CREATE TABLE delivery_orders (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants(id),
  from_warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  to_warehouse_id   UUID REFERENCES warehouses(id),    -- NULL = external customer

  do_number         TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','picking','packed','dispatched','in_transit','delivered','failed','cancelled')),

  recipient_name    TEXT,
  recipient_address TEXT,
  recipient_phone   TEXT,

  driver_id         UUID REFERENCES profiles(id),
  vehicle_plate     TEXT,
  courier           TEXT,                -- nama kurir/ekspedisi jika outsource

  scheduled_at      TIMESTAMPTZ,
  dispatched_at     TIMESTAMPTZ,
  delivered_at      TIMESTAMPTZ,

  -- ePOD (Electronic Proof of Delivery)
  epod_signed_by    TEXT,
  epod_signed_at    TIMESTAMPTZ,
  epod_signature_url TEXT,   -- Supabase Storage
  epod_photo_url    TEXT,

  -- GPS tracking
  last_lat          NUMERIC(10, 7),
  last_lng          NUMERIC(10, 7),
  last_location_at  TIMESTAMPTZ,

  notes             TEXT,
  metadata          JSONB NOT NULL DEFAULT '{}',

  created_by        UUID REFERENCES profiles(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, do_number)
);

CREATE TABLE do_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  do_id           UUID NOT NULL REFERENCES delivery_orders(id) ON DELETE CASCADE,
  product_id      UUID NOT NULL REFERENCES products(id),
  lot_id          UUID NOT NULL REFERENCES stock_lots(id),
  bin_id          UUID REFERENCES warehouse_bins(id),

  qty_ordered     NUMERIC(12, 4) NOT NULL,
  qty_picked      NUMERIC(12, 4) NOT NULL DEFAULT 0,
  qty_delivered   NUMERIC(12, 4),
  uom             TEXT NOT NULL,

  unit_price      NUMERIC(15, 4),
  notes           TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_do_tenant   ON delivery_orders(tenant_id);
CREATE INDEX idx_do_status   ON delivery_orders(tenant_id, status);
CREATE INDEX idx_do_driver   ON delivery_orders(driver_id) WHERE driver_id IS NOT NULL;
CREATE INDEX idx_do_lines    ON do_lines(do_id);

CREATE TRIGGER trg_do_updated_at
  BEFORE UPDATE ON delivery_orders
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- RETURN ORDERS  — Retur ke supplier atau dari unit
-- =============================================================================
CREATE TABLE return_orders (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
  supplier_id     UUID REFERENCES suppliers(id),      -- NULL = internal return
  grn_id          UUID REFERENCES goods_receipts(id),
  po_id           UUID REFERENCES purchase_orders(id),

  return_number   TEXT NOT NULL,
  direction       TEXT NOT NULL DEFAULT 'to_supplier'
                  CHECK (direction IN ('to_supplier','from_unit','from_customer')),
  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft','submitted','approved','shipped','completed','cancelled')),

  reason          TEXT NOT NULL,
  return_type     TEXT NOT NULL DEFAULT 'defective'
                  CHECK (return_type IN ('defective','expired','wrong_item','overdelivery','recall','other')),

  credit_note_no  TEXT,    -- nomor credit note dari supplier
  refund_amount   NUMERIC(18, 2),
  currency        currency_code NOT NULL DEFAULT 'IDR',

  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,
  shipped_at      TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,

  notes           TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, return_number)
);

CREATE TABLE return_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  return_id       UUID NOT NULL REFERENCES return_orders(id) ON DELETE CASCADE,
  product_id      UUID NOT NULL REFERENCES products(id),
  lot_id          UUID REFERENCES stock_lots(id),
  grn_line_id     UUID REFERENCES grn_lines(id),

  qty_returned    NUMERIC(12, 4) NOT NULL,
  uom             TEXT NOT NULL,
  unit_price      NUMERIC(15, 4),
  total_price     NUMERIC(18, 2),
  reason          TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_returns_tenant ON return_orders(tenant_id);
CREATE INDEX idx_returns_status ON return_orders(tenant_id, status);
CREATE INDEX idx_return_lines   ON return_lines(return_id);

CREATE TRIGGER trg_returns_updated_at
  BEFORE UPDATE ON return_orders
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================
ALTER TABLE goods_receipts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE grn_lines        ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_orders  ENABLE ROW LEVEL SECURITY;
ALTER TABLE do_lines         ENABLE ROW LEVEL SECURITY;
ALTER TABLE return_orders    ENABLE ROW LEVEL SECURITY;
ALTER TABLE return_lines     ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'goods_receipts','grn_lines',
    'delivery_orders','do_lines',
    'return_orders','return_lines'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;

-- =============================================================================
-- END  04_m3_order.sql
-- =============================================================================

-- =============================================================================
-- TransLOG-X  |  02_m1_inventory.sql
-- M1: Inventory Management — warehouse locations, products, stock, lots, movements
-- All tables are tenant-isolated via RLS
-- =============================================================================

-- =============================================================================
-- WAREHOUSES  — Gudang milik tenant (RS / PBF / distributor)
-- =============================================================================
CREATE TABLE warehouses (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  code            TEXT NOT NULL,
  name            TEXT NOT NULL,
  type            TEXT NOT NULL DEFAULT 'main'
                  CHECK (type IN ('main','satellite','cold_room','pharmacy','emergency','consignment')),
  address         TEXT,
  city            TEXT,
  province        TEXT,
  lat             NUMERIC(10, 7),
  lng             NUMERIC(10, 7),
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  has_cold_room   BOOLEAN NOT NULL DEFAULT FALSE,
  min_temp_c      NUMERIC(5, 2),     -- minimum suhu cold storage
  max_temp_c      NUMERIC(5, 2),     -- maximum suhu cold storage
  manager_id      UUID REFERENCES profiles(id),
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

CREATE INDEX idx_warehouses_tenant ON warehouses(tenant_id);

CREATE TRIGGER trg_warehouses_updated_at
  BEFORE UPDATE ON warehouses
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- WAREHOUSE ZONES & BINS  — Lokasi penyimpanan (rak, bin, zona)
-- =============================================================================
CREATE TABLE warehouse_zones (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id  UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  tenant_id     UUID NOT NULL REFERENCES tenants(id),
  code          TEXT NOT NULL,
  name          TEXT NOT NULL,
  zone_type     TEXT DEFAULT 'general'
                CHECK (zone_type IN ('general','cold','frozen','controlled','flammable','quarantine','return')),
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (warehouse_id, code)
);

CREATE INDEX idx_zones_warehouse ON warehouse_zones(warehouse_id);
CREATE INDEX idx_zones_tenant    ON warehouse_zones(tenant_id);

CREATE TABLE warehouse_bins (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_id     UUID NOT NULL REFERENCES warehouse_zones(id) ON DELETE CASCADE,
  tenant_id   UUID NOT NULL REFERENCES tenants(id),
  code        TEXT NOT NULL,                -- e.g., A-01-01 (aisle-rack-shelf)
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  capacity    NUMERIC(10, 2),
  uom         TEXT DEFAULT 'unit',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (zone_id, code)
);

CREATE INDEX idx_bins_zone   ON warehouse_bins(zone_id);
CREATE INDEX idx_bins_tenant ON warehouse_bins(tenant_id);

-- =============================================================================
-- PRODUCTS  — Katalog produk milik tenant (merujuk ke KFA)
-- Tenant bisa rename, set harga jual, dan konfigurasi stok sendiri
-- =============================================================================
CREATE TABLE products (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

  -- KFA reference (nullable: produk non-KFA juga bisa ada)
  kfa_code          TEXT REFERENCES kfa_drugs(kfa_code),
  kfa_alkes_code    TEXT REFERENCES kfa_alkes(kfa_code),

  -- Identity
  internal_code     TEXT,                  -- kode item internal RS
  barcode           TEXT,
  name              TEXT NOT NULL,
  brand             TEXT,
  category          product_category NOT NULL DEFAULT 'obat',
  sub_category      TEXT,
  description       TEXT,

  -- Units
  uom_base          TEXT NOT NULL DEFAULT 'tablet',    -- satuan terkecil
  uom_purchase      TEXT,                              -- satuan beli (box, karton)
  uom_conversion    NUMERIC(10, 4) NOT NULL DEFAULT 1, -- 1 box = N tablet

  -- Pricing
  last_purchase_price NUMERIC(15, 2),
  standard_price    NUMERIC(15, 2),
  selling_price     NUMERIC(15, 2),
  currency          currency_code NOT NULL DEFAULT 'IDR',

  -- Stock rules
  min_stock         NUMERIC(12, 4) NOT NULL DEFAULT 0,
  max_stock         NUMERIC(12, 4),
  reorder_point     NUMERIC(12, 4),
  reorder_qty       NUMERIC(12, 4),
  lead_time_days    INT NOT NULL DEFAULT 7,

  -- Regulatory
  nie               TEXT,
  nie_expired_at    DATE,
  is_narkotika      BOOLEAN NOT NULL DEFAULT FALSE,
  is_psikotropika   BOOLEAN NOT NULL DEFAULT FALSE,
  is_fornas         BOOLEAN NOT NULL DEFAULT FALSE,
  requires_recipe   BOOLEAN NOT NULL DEFAULT FALSE,
  storage_condition storage_condition NOT NULL DEFAULT 'room_temp',

  -- Status
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  is_formulary      BOOLEAN NOT NULL DEFAULT FALSE,   -- masuk formularium RS
  discontinued_at   TIMESTAMPTZ,

  metadata          JSONB NOT NULL DEFAULT '{}',
  created_by        UUID REFERENCES profiles(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, internal_code),
  CONSTRAINT kfa_exclusive CHECK (
    NOT (kfa_code IS NOT NULL AND kfa_alkes_code IS NOT NULL)
  )
);

CREATE INDEX idx_products_tenant        ON products(tenant_id);
CREATE INDEX idx_products_kfa           ON products(kfa_code);
CREATE INDEX idx_products_kfa_alkes     ON products(kfa_alkes_code);
CREATE INDEX idx_products_category      ON products(tenant_id, category);
CREATE INDEX idx_products_name          ON products USING gin(name gin_trgm_ops);
CREATE INDEX idx_products_barcode       ON products(tenant_id, barcode);
CREATE INDEX idx_products_active        ON products(tenant_id, is_active);

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- STOCK LOTS  — Lot/batch tracking per produk per gudang
-- =============================================================================
CREATE TABLE stock_lots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  product_id      UUID NOT NULL REFERENCES products(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
  bin_id          UUID REFERENCES warehouse_bins(id),

  lot_number      TEXT NOT NULL,
  batch_number    TEXT,
  serial_numbers  TEXT[],                -- untuk alkes dengan serialisasi BPOM

  qty_on_hand     NUMERIC(12, 4) NOT NULL DEFAULT 0,
  qty_reserved    NUMERIC(12, 4) NOT NULL DEFAULT 0,  -- reserved for picking
  qty_available   NUMERIC(12, 4) GENERATED ALWAYS AS (qty_on_hand - qty_reserved) STORED,

  manufactured_at DATE,
  expired_at      DATE NOT NULL,         -- mandatory: FEFO enforcement
  received_at     DATE NOT NULL DEFAULT CURRENT_DATE,

  supplier_id     UUID,                  -- FK to suppliers (set in 03_m2)
  po_id           UUID,                  -- FK to purchase_orders (set in 03_m2)
  grn_id          UUID,                  -- FK to goods_receipts (set in 04_m3)

  purchase_price  NUMERIC(15, 2),
  currency        currency_code NOT NULL DEFAULT 'IDR',

  status          TEXT NOT NULL DEFAULT 'available'
                  CHECK (status IN ('available','quarantine','reserved','recalled','expired','disposed')),

  is_bpom_reported BOOLEAN NOT NULL DEFAULT FALSE,    -- sudah lapor BPOM TTAC?
  bpom_ttac_ref    TEXT,

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, product_id, warehouse_id, lot_number)
);

CREATE INDEX idx_lots_tenant      ON stock_lots(tenant_id);
CREATE INDEX idx_lots_product     ON stock_lots(tenant_id, product_id);
CREATE INDEX idx_lots_warehouse   ON stock_lots(warehouse_id);
CREATE INDEX idx_lots_expiry      ON stock_lots(expired_at);          -- FEFO queries
CREATE INDEX idx_lots_status      ON stock_lots(tenant_id, status);

CREATE TRIGGER trg_lots_updated_at
  BEFORE UPDATE ON stock_lots
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- STOCK SUMMARY  — Agregasi stok per produk per gudang (denormalized, fast read)
-- Diupdate via trigger dari stock_movements
-- =============================================================================
CREATE TABLE stock_summary (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  product_id      UUID NOT NULL REFERENCES products(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),

  qty_on_hand     NUMERIC(12, 4) NOT NULL DEFAULT 0,
  qty_reserved    NUMERIC(12, 4) NOT NULL DEFAULT 0,
  qty_in_transit  NUMERIC(12, 4) NOT NULL DEFAULT 0,
  qty_available   NUMERIC(12, 4) GENERATED ALWAYS AS (qty_on_hand - qty_reserved) STORED,

  nearest_expiry  DATE,          -- lot yang paling dekat expired
  avg_cost        NUMERIC(15, 4),
  last_movement_at TIMESTAMPTZ,

  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, product_id, warehouse_id)
);

CREATE INDEX idx_summary_tenant    ON stock_summary(tenant_id);
CREATE INDEX idx_summary_product   ON stock_summary(tenant_id, product_id);
CREATE INDEX idx_summary_low_stock ON stock_summary(tenant_id, qty_available)
  WHERE qty_available >= 0;

-- =============================================================================
-- STOCK MOVEMENTS  — Ledger semua pergerakan stok (immutable-style)
-- =============================================================================
CREATE TABLE stock_movements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  product_id      UUID NOT NULL REFERENCES products(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
  lot_id          UUID REFERENCES stock_lots(id),
  bin_id          UUID REFERENCES warehouse_bins(id),

  movement_type   movement_type NOT NULL,
  qty             NUMERIC(12, 4) NOT NULL,           -- positif = masuk, negatif = keluar
  qty_before      NUMERIC(12, 4) NOT NULL,
  qty_after       NUMERIC(12, 4) NOT NULL,

  -- Reference to source document
  ref_type        TEXT,   -- 'grn', 'picking', 'transfer', 'adjustment', 'po', 'shipment'
  ref_id          UUID,
  ref_number      TEXT,

  -- Target (for transfers)
  to_warehouse_id UUID REFERENCES warehouses(id),
  to_bin_id       UUID REFERENCES warehouse_bins(id),

  unit_cost       NUMERIC(15, 4),
  notes           TEXT,
  performed_by    UUID REFERENCES profiles(id),

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
  -- NO updated_at — movements are append-only
);

CREATE INDEX idx_movements_tenant    ON stock_movements(tenant_id, created_at DESC);
CREATE INDEX idx_movements_product   ON stock_movements(tenant_id, product_id, created_at DESC);
CREATE INDEX idx_movements_lot       ON stock_movements(lot_id);
CREATE INDEX idx_movements_ref       ON stock_movements(ref_type, ref_id);

-- =============================================================================
-- REORDER RULES  — Konfigurasi auto-reorder per produk per gudang
-- =============================================================================
CREATE TABLE reorder_rules (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  product_id      UUID NOT NULL REFERENCES products(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),

  reorder_point   NUMERIC(12, 4) NOT NULL,
  reorder_qty     NUMERIC(12, 4) NOT NULL,
  max_stock       NUMERIC(12, 4),
  lead_time_days  INT NOT NULL DEFAULT 7,
  safety_stock    NUMERIC(12, 4) NOT NULL DEFAULT 0,

  preferred_supplier_id UUID,           -- FK to suppliers (set in 03_m2)
  auto_create_pr        BOOLEAN NOT NULL DEFAULT TRUE,

  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  last_triggered_at TIMESTAMPTZ,

  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, product_id, warehouse_id)
);

CREATE INDEX idx_reorder_tenant  ON reorder_rules(tenant_id);
CREATE INDEX idx_reorder_active  ON reorder_rules(tenant_id, is_active) WHERE is_active = TRUE;

CREATE TRIGGER trg_reorder_updated_at
  BEFORE UPDATE ON reorder_rules
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- STOCK COUNT SESSIONS  — Opname / stock count
-- =============================================================================
CREATE TABLE stock_count_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
  session_number  TEXT NOT NULL,

  count_type      TEXT NOT NULL DEFAULT 'full'
                  CHECK (count_type IN ('full','cycle','spot')),
  status          TEXT NOT NULL DEFAULT 'planned'
                  CHECK (status IN ('planned','in_progress','pending_approval','approved','cancelled')),

  scheduled_at    TIMESTAMPTZ NOT NULL,
  started_at      TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,

  assigned_to     UUID[] DEFAULT '{}',   -- array of profile IDs
  approved_by     UUID REFERENCES profiles(id),
  approved_at     TIMESTAMPTZ,

  notes           TEXT,
  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, session_number)
);

CREATE TABLE stock_count_lines (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants(id),
  session_id        UUID NOT NULL REFERENCES stock_count_sessions(id) ON DELETE CASCADE,
  product_id        UUID NOT NULL REFERENCES products(id),
  lot_id            UUID REFERENCES stock_lots(id),
  bin_id            UUID REFERENCES warehouse_bins(id),

  system_qty        NUMERIC(12, 4) NOT NULL,     -- stok menurut sistem
  counted_qty       NUMERIC(12, 4),               -- stok hasil hitung fisik
  variance_qty      NUMERIC(12, 4)
    GENERATED ALWAYS AS (counted_qty - system_qty) STORED,

  counted_by        UUID REFERENCES profiles(id),
  counted_at        TIMESTAMPTZ,
  verified_by       UUID REFERENCES profiles(id),
  notes             TEXT,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_count_session   ON stock_count_lines(session_id);
CREATE INDEX idx_count_tenant    ON stock_count_sessions(tenant_id);
CREATE TRIGGER trg_count_session_updated_at
  BEFORE UPDATE ON stock_count_sessions
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- TRIGGER: update stock_summary after stock_movement
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_update_stock_summary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO stock_summary (
    tenant_id, product_id, warehouse_id,
    qty_on_hand, qty_reserved, last_movement_at
  )
  VALUES (
    NEW.tenant_id, NEW.product_id, NEW.warehouse_id,
    GREATEST(0, NEW.qty_after), 0, NEW.created_at
  )
  ON CONFLICT (tenant_id, product_id, warehouse_id)
  DO UPDATE SET
    qty_on_hand      = GREATEST(0, stock_summary.qty_on_hand + NEW.qty),
    last_movement_at = NEW.created_at,
    updated_at       = NOW();

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_stock_movements_summary
  AFTER INSERT ON stock_movements
  FOR EACH ROW EXECUTE FUNCTION fn_update_stock_summary();

-- =============================================================================
-- MATERIALIZED VIEW: products below reorder point (for reorder alert)
-- Refresh: scheduled via pg_cron or Supabase Edge Function cron
-- =============================================================================
CREATE MATERIALIZED VIEW mv_low_stock_alert AS
  SELECT
    ss.tenant_id,
    ss.product_id,
    p.name                          AS product_name,
    p.internal_code,
    ss.warehouse_id,
    w.name                          AS warehouse_name,
    ss.qty_available,
    rr.reorder_point,
    rr.reorder_qty,
    rr.lead_time_days,
    rr.preferred_supplier_id,
    rr.auto_create_pr,
    ss.nearest_expiry,
    NOW()                           AS generated_at
  FROM stock_summary ss
  JOIN products p        ON p.id = ss.product_id
  JOIN warehouses w      ON w.id = ss.warehouse_id
  JOIN reorder_rules rr  ON rr.product_id = ss.product_id
                        AND rr.warehouse_id = ss.warehouse_id
                        AND rr.is_active = TRUE
  WHERE ss.qty_available <= rr.reorder_point
    AND p.is_active = TRUE;

CREATE INDEX idx_mv_low_stock_tenant ON mv_low_stock_alert(tenant_id);

-- =============================================================================
-- ROW LEVEL SECURITY  — tenant isolation
-- =============================================================================

ALTER TABLE warehouses          ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_zones     ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_bins      ENABLE ROW LEVEL SECURITY;
ALTER TABLE products            ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_lots          ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_summary       ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements     ENABLE ROW LEVEL SECURITY;
ALTER TABLE reorder_rules       ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_count_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_count_lines   ENABLE ROW LEVEL SECURITY;

-- Generic tenant isolation policy (create for each table)
DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'warehouses', 'warehouse_zones', 'warehouse_bins',
    'products', 'stock_lots', 'stock_summary', 'stock_movements',
    'reorder_rules', 'stock_count_sessions', 'stock_count_lines'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;

-- =============================================================================
-- END  02_m1_inventory.sql
-- =============================================================================

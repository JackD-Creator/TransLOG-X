-- =============================================================================
-- TransLOG-X  |  05_m4_warehouse.sql
-- M4: Warehouse & Distribution — picking, packing, shipments, cold chain, GPS
-- =============================================================================

-- =============================================================================
-- PICKING ORDERS  — Order picking untuk memenuhi delivery order
-- =============================================================================
CREATE TABLE picking_orders (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
  do_id           UUID REFERENCES delivery_orders(id),

  pick_number     TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','assigned','in_progress','completed','cancelled')),

  assigned_to     UUID REFERENCES profiles(id),
  assigned_at     TIMESTAMPTZ,
  started_at      TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,

  pick_method     TEXT DEFAULT 'fefo'
                  CHECK (pick_method IN ('fefo','fifo','manual')),

  notes           TEXT,
  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, pick_number)
);

CREATE TABLE picking_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  pick_id         UUID NOT NULL REFERENCES picking_orders(id) ON DELETE CASCADE,
  product_id      UUID NOT NULL REFERENCES products(id),
  lot_id          UUID NOT NULL REFERENCES stock_lots(id),
  from_bin_id     UUID REFERENCES warehouse_bins(id),

  qty_requested   NUMERIC(12, 4) NOT NULL,
  qty_picked      NUMERIC(12, 4) NOT NULL DEFAULT 0,
  uom             TEXT NOT NULL,

  picked_by       UUID REFERENCES profiles(id),
  picked_at       TIMESTAMPTZ,
  scan_verified   BOOLEAN NOT NULL DEFAULT FALSE,   -- barcode scan confirmed

  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_picking_tenant  ON picking_orders(tenant_id);
CREATE INDEX idx_picking_status  ON picking_orders(tenant_id, status);
CREATE INDEX idx_picking_lines   ON picking_lines(pick_id);

CREATE TRIGGER trg_picking_updated_at
  BEFORE UPDATE ON picking_orders
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- PACKING SLIPS
-- =============================================================================
CREATE TABLE packing_slips (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  do_id           UUID NOT NULL REFERENCES delivery_orders(id),
  pick_id         UUID REFERENCES picking_orders(id),

  slip_number     TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'packing'
                  CHECK (status IN ('packing','packed','dispatched')),

  packed_by       UUID REFERENCES profiles(id),
  packed_at       TIMESTAMPTZ,
  total_weight_kg NUMERIC(8, 3),
  total_volume_m3 NUMERIC(8, 4),
  box_count       INT,
  seal_number     TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, slip_number)
);

CREATE TRIGGER trg_packing_updated_at
  BEFORE UPDATE ON packing_slips
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- SHIPMENTS  — Pengiriman ke customer / unit RS
-- =============================================================================
CREATE TABLE shipments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants(id),
  do_id             UUID NOT NULL REFERENCES delivery_orders(id),
  packing_slip_id   UUID REFERENCES packing_slips(id),

  shipment_number   TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','picked_up','in_transit','out_for_delivery','delivered','failed','returned')),

  carrier_type      TEXT DEFAULT 'own_fleet'
                    CHECK (carrier_type IN ('own_fleet','third_party','kurir')),
  carrier_name      TEXT,
  tracking_number   TEXT,

  origin_address    TEXT,
  dest_address      TEXT NOT NULL,
  dest_lat          NUMERIC(10, 7),
  dest_lng          NUMERIC(10, 7),

  scheduled_at      TIMESTAMPTZ,
  pickup_at         TIMESTAMPTZ,
  estimated_at      TIMESTAMPTZ,
  delivered_at      TIMESTAMPTZ,

  driver_id         UUID REFERENCES profiles(id),
  vehicle_plate     TEXT,

  -- ePOD
  epod_signed_by    TEXT,
  epod_signed_at    TIMESTAMPTZ,
  epod_signature_url TEXT,
  epod_photos       TEXT[] DEFAULT '{}',

  notes             TEXT,
  metadata          JSONB NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, shipment_number)
);

CREATE INDEX idx_shipments_tenant  ON shipments(tenant_id);
CREATE INDEX idx_shipments_status  ON shipments(tenant_id, status);
CREATE INDEX idx_shipments_driver  ON shipments(driver_id) WHERE driver_id IS NOT NULL;

CREATE TRIGGER trg_shipments_updated_at
  BEFORE UPDATE ON shipments
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- GPS TRACKING EVENTS  — Riwayat posisi driver
-- =============================================================================
CREATE TABLE gps_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES tenants(id),
  shipment_id   UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
  driver_id     UUID REFERENCES profiles(id),

  lat           NUMERIC(10, 7) NOT NULL,
  lng           NUMERIC(10, 7) NOT NULL,
  accuracy_m    NUMERIC(6, 2),
  speed_kmh     NUMERIC(5, 2),
  heading       NUMERIC(5, 2),   -- degrees 0-360
  event_type    TEXT DEFAULT 'location'
                CHECK (event_type IN ('location','pickup','delivery','stop','deviation','arrived')),

  recorded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
  -- No updated_at — append-only
);

CREATE INDEX idx_gps_shipment ON gps_events(shipment_id, recorded_at DESC);
CREATE INDEX idx_gps_driver   ON gps_events(driver_id, recorded_at DESC);

-- =============================================================================
-- COLD CHAIN TEMPERATURE LOGS  — IoT sensor dari cold storage / reefer truck
-- =============================================================================
CREATE TABLE temperature_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL REFERENCES tenants(id),

  source_type   TEXT NOT NULL
                CHECK (source_type IN ('warehouse','shipment','bin')),
  source_id     UUID NOT NULL,   -- FK ke warehouses / shipments / bins

  sensor_id     TEXT NOT NULL,   -- ID sensor IoT
  temp_celsius  NUMERIC(5, 2) NOT NULL,
  humidity_pct  NUMERIC(5, 2),

  is_excursion  BOOLEAN NOT NULL DEFAULT FALSE,
  excursion_type TEXT,            -- 'over_limit','under_limit'
  alert_sent    BOOLEAN NOT NULL DEFAULT FALSE,

  recorded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_temp_source   ON temperature_logs(source_type, source_id, recorded_at DESC);
CREATE INDEX idx_temp_excursion ON temperature_logs(tenant_id, is_excursion, recorded_at DESC)
  WHERE is_excursion = TRUE;

-- =============================================================================
-- VEHICLE FLEET
-- =============================================================================
CREATE TABLE vehicles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  plate_number    TEXT NOT NULL,
  vehicle_type    TEXT NOT NULL DEFAULT 'motorcycle'
                  CHECK (vehicle_type IN ('motorcycle','car','van','pickup','truck','reefer_truck')),
  brand           TEXT,
  model           TEXT,
  year            INT,
  has_cold_chain  BOOLEAN NOT NULL DEFAULT FALSE,
  capacity_kg     NUMERIC(8, 2),
  status          TEXT NOT NULL DEFAULT 'available'
                  CHECK (status IN ('available','in_use','maintenance','inactive')),
  current_driver_id UUID REFERENCES profiles(id),
  last_service_at DATE,
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, plate_number)
);

CREATE TRIGGER trg_vehicles_updated_at
  BEFORE UPDATE ON vehicles
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- ROUTE OPTIMIZATION JOBS  — Hasil kalkulasi rute AI
-- =============================================================================
CREATE TABLE route_plans (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  vehicle_id      UUID REFERENCES vehicles(id),
  driver_id       UUID REFERENCES profiles(id),

  plan_date       DATE NOT NULL,
  status          TEXT NOT NULL DEFAULT 'planned'
                  CHECK (status IN ('planned','in_progress','completed','cancelled')),

  waypoints       JSONB NOT NULL DEFAULT '[]',  -- array of {lat, lng, do_id, seq}
  total_distance_km NUMERIC(8, 2),
  estimated_duration_min INT,
  optimization_score NUMERIC(5, 2),

  shipment_ids    UUID[] DEFAULT '{}',

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_routes_tenant ON route_plans(tenant_id);
CREATE INDEX idx_routes_date   ON route_plans(tenant_id, plan_date);
CREATE TRIGGER trg_routes_updated_at
  BEFORE UPDATE ON route_plans
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- WAREHOUSE TRANSFER REQUESTS  — Transfer antar gudang
-- =============================================================================
CREATE TABLE warehouse_transfers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         UUID NOT NULL REFERENCES tenants(id),
  from_warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  to_warehouse_id   UUID NOT NULL REFERENCES warehouses(id),

  transfer_number   TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','approved','in_transit','completed','cancelled')),

  reason            TEXT,
  approved_by       UUID REFERENCES profiles(id),
  approved_at       TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  notes             TEXT,

  created_by        UUID REFERENCES profiles(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, transfer_number),
  CHECK (from_warehouse_id <> to_warehouse_id)
);

CREATE TABLE warehouse_transfer_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  transfer_id     UUID NOT NULL REFERENCES warehouse_transfers(id) ON DELETE CASCADE,
  product_id      UUID NOT NULL REFERENCES products(id),
  lot_id          UUID NOT NULL REFERENCES stock_lots(id),
  from_bin_id     UUID REFERENCES warehouse_bins(id),
  to_bin_id       UUID REFERENCES warehouse_bins(id),

  qty_requested   NUMERIC(12, 4) NOT NULL,
  qty_transferred NUMERIC(12, 4),
  uom             TEXT NOT NULL,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transfers_tenant ON warehouse_transfers(tenant_id);
CREATE TRIGGER trg_transfers_updated_at
  BEFORE UPDATE ON warehouse_transfers
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================
ALTER TABLE picking_orders         ENABLE ROW LEVEL SECURITY;
ALTER TABLE picking_lines          ENABLE ROW LEVEL SECURITY;
ALTER TABLE packing_slips          ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments              ENABLE ROW LEVEL SECURITY;
ALTER TABLE gps_events             ENABLE ROW LEVEL SECURITY;
ALTER TABLE temperature_logs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE route_plans            ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_transfers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_transfer_lines ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'picking_orders','picking_lines','packing_slips',
    'shipments','gps_events','temperature_logs',
    'vehicles','route_plans',
    'warehouse_transfers','warehouse_transfer_lines'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;

-- =============================================================================
-- END  05_m4_warehouse.sql
-- =============================================================================

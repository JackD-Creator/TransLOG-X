-- =============================================================================
-- TransLOG-X  |  01_kfa_catalog.sql
-- KFA Master Catalog: obat (24,353) + alkes (69,492) + FORNAS 2025 (711)
-- Source: SATUSEHAT Kemkes API — KMK HK.01.07/MENKES/1199/2025
-- These are GLOBAL reference tables (no tenant_id — shared across all tenants)
-- =============================================================================

-- =============================================================================
-- KFA DRUGS  — Katalog Farmasi Obat
-- =============================================================================
CREATE TABLE kfa_drugs (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kfa_code            TEXT NOT NULL UNIQUE,        -- kode KFA Kemkes
  name                TEXT NOT NULL,               -- nama generik resmi
  nama_dagang         TEXT,                        -- nama brand/dagang
  generik             BOOLEAN NOT NULL DEFAULT FALSE,
  active_ingredients  TEXT,                        -- zat aktif (bisa multiple)
  dosage_form         TEXT,                        -- tablet, kapsul, injeksi, dll
  strength            TEXT,                        -- kekuatan: 500mg, 10mg/mL, dll
  farmalkes_type      TEXT,                        -- kelompok farmalkes
  manufacturer        TEXT,
  distributor         TEXT,
  nie                 TEXT,                        -- Nomor Izin Edar BPOM
  nie_expired_at      DATE,
  fix_price           NUMERIC(15, 2),              -- Harga Acuan Pemerintah (HAP)
  het_price           NUMERIC(15, 2),              -- Harga Eceran Tertinggi
  uom                 TEXT NOT NULL DEFAULT 'tablet',
  is_fornas           BOOLEAN NOT NULL DEFAULT FALSE,  -- masuk Formularium Nasional
  is_narkotika        BOOLEAN NOT NULL DEFAULT FALSE,
  is_psikotropika     BOOLEAN NOT NULL DEFAULT FALSE,
  is_prekursor        BOOLEAN NOT NULL DEFAULT FALSE,
  is_obat_keras       BOOLEAN NOT NULL DEFAULT FALSE,
  storage_condition   storage_condition NOT NULL DEFAULT 'room_temp',
  kelas_terapi        TEXT,                        -- ATC classification
  kode_atc            TEXT,                        -- WHO ATC code
  metadata            JSONB NOT NULL DEFAULT '{}',
  last_synced_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_kfa_drugs_name      ON kfa_drugs USING gin(name gin_trgm_ops);
CREATE INDEX idx_kfa_drugs_dagang    ON kfa_drugs USING gin(nama_dagang gin_trgm_ops);
CREATE INDEX idx_kfa_drugs_nie       ON kfa_drugs(nie);
CREATE INDEX idx_kfa_drugs_fornas    ON kfa_drugs(is_fornas) WHERE is_fornas = TRUE;
CREATE INDEX idx_kfa_drugs_generik   ON kfa_drugs(generik);
CREATE INDEX idx_kfa_drugs_narkotika ON kfa_drugs(is_narkotika) WHERE is_narkotika = TRUE;

CREATE TRIGGER trg_kfa_drugs_updated_at
  BEFORE UPDATE ON kfa_drugs
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- KFA ALKES  — Katalog Alat Kesehatan
-- =============================================================================
CREATE TABLE kfa_alkes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kfa_code            TEXT NOT NULL UNIQUE,
  name                TEXT NOT NULL,
  farmalkes_type      TEXT,
  med_dev_jenis       TEXT,                        -- jenis alkes
  med_dev_kategori    TEXT,                        -- kategori alkes
  med_dev_kelas_risiko TEXT,                       -- Kelas I, II, III
  manufacturer        TEXT,
  distributor         TEXT,
  nie                 TEXT,                        -- Nomor Izin Edar alkes
  nie_expired_at      DATE,
  fix_price           NUMERIC(15, 2),
  uom                 TEXT NOT NULL DEFAULT 'pcs',
  storage_condition   storage_condition NOT NULL DEFAULT 'room_temp',
  is_implant          BOOLEAN NOT NULL DEFAULT FALSE,
  is_steril           BOOLEAN NOT NULL DEFAULT FALSE,
  metadata            JSONB NOT NULL DEFAULT '{}',
  last_synced_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_kfa_alkes_name     ON kfa_alkes USING gin(name gin_trgm_ops);
CREATE INDEX idx_kfa_alkes_nie      ON kfa_alkes(nie);
CREATE INDEX idx_kfa_alkes_jenis    ON kfa_alkes(med_dev_jenis);
CREATE INDEX idx_kfa_alkes_kelas    ON kfa_alkes(med_dev_kelas_risiko);

CREATE TRIGGER trg_kfa_alkes_updated_at
  BEFORE UPDATE ON kfa_alkes
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- FORNAS 2025  — Formularium Nasional
-- KMK HK.01.07/MENKES/1199/2025, berlaku 1 April 2026
-- =============================================================================
CREATE TABLE fornas_drugs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kfa_code        TEXT UNIQUE REFERENCES kfa_drugs(kfa_code),
  name            TEXT NOT NULL,
  generik         BOOLEAN NOT NULL DEFAULT TRUE,
  kelas_terapi    TEXT,
  sub_kelas       TEXT,
  restriksi       TEXT,                 -- restriksi penggunaan oleh Kemenkes
  fasilitas       TEXT,                 -- faskes yang boleh meresepkan
  fornas_level    TEXT,                 -- Tingkat I, II, III
  kmk_ref         TEXT DEFAULT 'HK.01.07/MENKES/1199/2025',
  effective_date  DATE NOT NULL DEFAULT '2026-04-01',
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fornas_name        ON fornas_drugs USING gin(name gin_trgm_ops);
CREATE INDEX idx_fornas_kelas       ON fornas_drugs(kelas_terapi);
CREATE INDEX idx_fornas_kfa_code    ON fornas_drugs(kfa_code);

CREATE TRIGGER trg_fornas_updated_at
  BEFORE UPDATE ON fornas_drugs
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- UNIFIED CATALOG VIEW  — search obat + alkes sekaligus
-- =============================================================================
CREATE OR REPLACE VIEW v_kfa_catalog AS
  SELECT
    id,
    kfa_code,
    name,
    nama_dagang,
    'obat'::TEXT                      AS catalog_type,
    farmalkes_type,
    manufacturer,
    nie,
    fix_price,
    het_price,
    uom,
    storage_condition,
    is_fornas,
    is_narkotika,
    is_psikotropika
  FROM kfa_drugs
  WHERE nie IS NOT NULL
UNION ALL
  SELECT
    id,
    kfa_code,
    name,
    NULL                              AS nama_dagang,
    'alkes'::TEXT                     AS catalog_type,
    farmalkes_type,
    manufacturer,
    nie,
    fix_price,
    NULL                              AS het_price,
    uom,
    storage_condition,
    FALSE                             AS is_fornas,
    FALSE                             AS is_narkotika,
    FALSE                             AS is_psikotropika
  FROM kfa_alkes;

-- =============================================================================
-- RLS — KFA tables are global reference, readable by all authenticated users
-- No tenant isolation needed (public catalog data)
-- =============================================================================

ALTER TABLE kfa_drugs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE kfa_alkes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE fornas_drugs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kfa_drugs_read_all"
  ON kfa_drugs FOR SELECT
  USING (auth.role() IN ('authenticated', 'service_role'));

CREATE POLICY "kfa_drugs_write_service"
  ON kfa_drugs FOR ALL
  USING (is_service_role());

CREATE POLICY "kfa_alkes_read_all"
  ON kfa_alkes FOR SELECT
  USING (auth.role() IN ('authenticated', 'service_role'));

CREATE POLICY "kfa_alkes_write_service"
  ON kfa_alkes FOR ALL
  USING (is_service_role());

CREATE POLICY "fornas_read_all"
  ON fornas_drugs FOR SELECT
  USING (auth.role() IN ('authenticated', 'service_role'));

CREATE POLICY "fornas_write_service"
  ON fornas_drugs FOR ALL
  USING (is_service_role());

-- =============================================================================
-- NOTE: Run seed files after this migration:
--   \i 'seeds data/kfa/seed_kfa_drugs.sql'
--   \i 'seeds data/kfa/seed_kfa_alkes.sql'
--   \i 'seeds data/kfa/seed_fornas_drugs.sql'
-- =============================================================================

-- =============================================================================
-- END  01_kfa_catalog.sql
-- =============================================================================

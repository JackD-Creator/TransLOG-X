-- Patch: tambah kolom KFA yang ada di seed tapi belum ada di schema

ALTER TABLE kfa_drugs
  ADD COLUMN IF NOT EXISTS farmalkes_group   VARCHAR(50),
  ADD COLUMN IF NOT EXISTS active            BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS state             VARCHAR(20),
  ADD COLUMN IF NOT EXISTS template_kfa_code VARCHAR(20),
  ADD COLUMN IF NOT EXISTS template_name     TEXT;

ALTER TABLE kfa_alkes
  ADD COLUMN IF NOT EXISTS nama_dagang         TEXT,
  ADD COLUMN IF NOT EXISTS farmalkes_group     VARCHAR(50),
  ADD COLUMN IF NOT EXISTS med_dev_subkategori TEXT,
  ADD COLUMN IF NOT EXISTS active              BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS state               VARCHAR(20),
  ADD COLUMN IF NOT EXISTS template_kfa_code   VARCHAR(20),
  ADD COLUMN IF NOT EXISTS template_name       TEXT;

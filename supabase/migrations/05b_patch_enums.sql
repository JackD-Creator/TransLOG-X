-- noTransaction
-- Patch: add 'cancelled' to financing_status enum
-- ALTER TYPE ADD VALUE cannot run inside a transaction block
ALTER TYPE financing_status ADD VALUE IF NOT EXISTS 'cancelled';

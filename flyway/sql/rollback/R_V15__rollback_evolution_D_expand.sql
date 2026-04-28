-- =====================================================================
-- R_V15__rollback_evolution_D_expand.sql
-- Rollback Évolution D - Phase 1 (EXPAND)
-- =====================================================================

DROP TRIGGER IF EXISTS trg_sync_patient_ssn_encryption ON patients;
DROP FUNCTION IF EXISTS sync_patient_ssn_encryption();

DROP INDEX IF EXISTS idx_patients_ssn_hash;
ALTER TABLE patients DROP COLUMN IF EXISTS ssn_encrypted;
ALTER TABLE patients DROP COLUMN IF EXISTS ssn_hash;

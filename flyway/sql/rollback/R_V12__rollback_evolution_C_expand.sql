-- =====================================================================
-- R_V12__rollback_evolution_C_expand.sql
-- Rollback Évolution C - Phase 1 (EXPAND)
-- =====================================================================

DROP TRIGGER IF EXISTS trg_sync_patient_gender_columns ON patients;
DROP FUNCTION IF EXISTS sync_patient_gender_columns();

ALTER TABLE patients DROP CONSTRAINT IF EXISTS fk_patients_gender_ref;
DROP INDEX IF EXISTS idx_patients_gender_code;
ALTER TABLE patients DROP COLUMN IF EXISTS gender_code;

-- Restaurer contrainte V1 stricte
ALTER TABLE patients DROP CONSTRAINT IF EXISTS patients_gender_check;
ALTER TABLE patients ADD CONSTRAINT patients_gender_check
    CHECK (gender IN ('M', 'F'));

DROP TABLE IF EXISTS gender_ref;

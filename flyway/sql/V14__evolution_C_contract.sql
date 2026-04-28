-- =====================================================================
-- V14__evolution_C_contract.sql
-- Évolution C - Phase 3 : CONTRACT
-- Suppression de l'ancien champ gender (CHAR(1))
-- =====================================================================

-- Supprimer le trigger de synchro
DROP TRIGGER IF EXISTS trg_sync_patient_gender_columns ON patients;
DROP FUNCTION IF EXISTS sync_patient_gender_columns();

-- Rendre gender_code NOT NULL
ALTER TABLE patients
    ALTER COLUMN gender_code SET NOT NULL;

-- Remplacer le champ gender par gender_code (VARCHAR)
ALTER TABLE patients DROP COLUMN gender;
ALTER TABLE patients RENAME COLUMN gender_code TO gender;

-- Contrainte explicite sur les valeurs V2
ALTER TABLE patients DROP CONSTRAINT IF EXISTS patients_gender_check;
ALTER TABLE patients ADD CONSTRAINT patients_gender_check
    CHECK (gender IN ('M', 'F', 'NB', 'U'));

COMMENT ON COLUMN patients.gender IS 'V2: genre étendu (FK gender_ref)';

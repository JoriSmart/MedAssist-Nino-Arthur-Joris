-- =====================================================================
-- R_V14__rollback_evolution_C_contract.sql
-- Rollback Évolution C - Phase 3 (CONTRACT)
-- =====================================================================

-- Revenir à gender_code + gender CHAR(1)
ALTER TABLE patients RENAME COLUMN gender TO gender_code;
ALTER TABLE patients ADD COLUMN gender CHAR(1) DEFAULT 'U';

UPDATE patients
SET gender = CASE
    WHEN gender_code IN ('M', 'F') THEN gender_code
    ELSE 'U'
END;

ALTER TABLE patients ALTER COLUMN gender SET NOT NULL;

-- Contrainte V1 (M/F/U)
ALTER TABLE patients DROP CONSTRAINT IF EXISTS patients_gender_check;
ALTER TABLE patients ADD CONSTRAINT patients_gender_check
    CHECK (gender IN ('M', 'F', 'U'));

-- Recréer trigger de synchro
CREATE OR REPLACE FUNCTION sync_patient_gender_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gender_code IS NULL AND NEW.gender IS NOT NULL THEN
        NEW.gender_code := CASE
            WHEN NEW.gender IN ('M', 'F') THEN NEW.gender
            ELSE 'U'
        END;
    END IF;

    IF NEW.gender_code IS NOT NULL THEN
        IF NEW.gender_code IN ('M', 'F') THEN
            NEW.gender := NEW.gender_code;
        ELSE
            NEW.gender := 'U';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_patient_gender_columns ON patients;
CREATE TRIGGER trg_sync_patient_gender_columns
BEFORE INSERT OR UPDATE ON patients
FOR EACH ROW
EXECUTE FUNCTION sync_patient_gender_columns();

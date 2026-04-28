-- =====================================================================
-- V12__evolution_C_expand.sql
-- Évolution C - Phase 1 : EXPAND
-- Ajout gender_ref + colonne gender_code (coexistence V1/V2)
-- =====================================================================

-- Table de référence des genres
CREATE TABLE IF NOT EXISTS gender_ref (
    code VARCHAR(10) PRIMARY KEY,
    label VARCHAR(50) NOT NULL
);

INSERT INTO gender_ref (code, label) VALUES
    ('M', 'Masculin'),
    ('F', 'Féminin'),
    ('NB', 'Non-binaire'),
    ('U', 'Inconnu / Non renseigné')
ON CONFLICT (code) DO NOTHING;

-- Relaxer la contrainte V1 pour autoriser 'U' (coexistence)
ALTER TABLE patients DROP CONSTRAINT IF EXISTS patients_gender_check;
ALTER TABLE patients ADD CONSTRAINT patients_gender_check
    CHECK (gender IN ('M', 'F', 'U'));

-- Ajouter la colonne V2
ALTER TABLE patients ADD COLUMN IF NOT EXISTS gender_code VARCHAR(10);
ALTER TABLE patients ADD CONSTRAINT fk_patients_gender_ref
    FOREIGN KEY (gender_code) REFERENCES gender_ref(code);

CREATE INDEX IF NOT EXISTS idx_patients_gender_code ON patients (gender_code);

-- Trigger de synchronisation V1 ↔ V2
CREATE OR REPLACE FUNCTION sync_patient_gender_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Si gender_code est NULL, le remplir depuis gender
    IF NEW.gender_code IS NULL AND NEW.gender IS NOT NULL THEN
        NEW.gender_code := CASE
            WHEN NEW.gender IN ('M', 'F') THEN NEW.gender
            ELSE 'U'
        END;
    END IF;

    -- Si gender_code est défini, maintenir gender (CHAR(1)) compatible
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

COMMENT ON TABLE gender_ref IS 'Référence des genres (M, F, NB, U)';
COMMENT ON COLUMN patients.gender_code IS 'V2: genre étendu (FK gender_ref)';

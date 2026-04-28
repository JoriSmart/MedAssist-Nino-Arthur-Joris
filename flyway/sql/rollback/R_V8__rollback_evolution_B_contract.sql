-- =====================================================================
-- R_V8__rollback_evolution_B_contract.sql
-- Rollback Évolution B - Phase 3 (CONTRACT)
-- =====================================================================

-- Recréer doctor_name
ALTER TABLE consultations ADD COLUMN IF NOT EXISTS doctor_name VARCHAR(200);

-- Reconstituer doctor_name depuis doctors
UPDATE consultations c
SET doctor_name = CONCAT('Dr. ', d.first_name, ' ', d.last_name)
FROM doctors d
WHERE c.doctor_id = d.id;

-- Rendre doctor_id nullable
ALTER TABLE consultations ALTER COLUMN doctor_id DROP NOT NULL;

-- Recréer index V1
DROP INDEX IF EXISTS idx_consultations_doctor_v2;
CREATE INDEX IF NOT EXISTS idx_consultations_doctor ON consultations (doctor_name);

-- Recréer fonctions + trigger de synchro (identique à EXPAND)
CREATE OR REPLACE FUNCTION doctor_name_matches(
    p_doctor_name VARCHAR,
    p_last_name VARCHAR,
    p_first_name VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        (p_last_name IS NOT NULL AND p_doctor_name ILIKE '%' || p_last_name || '%') OR
        (p_first_name IS NOT NULL AND p_doctor_name ILIKE '%' || p_first_name || '%')
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_consultation_doctor_to_table()
RETURNS TRIGGER AS $$
DECLARE
    v_doctor_id BIGINT;
BEGIN
    SELECT id INTO v_doctor_id FROM doctors
    WHERE doctor_name_matches(NEW.doctor_name, last_name, first_name)
    LIMIT 1;

    IF v_doctor_id IS NULL THEN
        INSERT INTO doctors (rpps_number, first_name, last_name)
        VALUES (
            'TEMP-' || MD5(NEW.doctor_name)::text,
            'Unknown',
            TRIM(NEW.doctor_name)
        )
        RETURNING id INTO v_doctor_id;
    END IF;

    NEW.doctor_id := v_doctor_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_consultation_doctor_to_table ON consultations;
CREATE TRIGGER trg_sync_consultation_doctor_to_table
BEFORE INSERT ON consultations
FOR EACH ROW
WHEN (NEW.doctor_name IS NOT NULL)
EXECUTE FUNCTION sync_consultation_doctor_to_table();

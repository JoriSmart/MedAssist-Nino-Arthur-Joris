-- =====================================================================
-- R_V17__rollback_evolution_D_contract.sql
-- Rollback Évolution D - Phase 3 (CONTRACT)
-- =====================================================================

-- Réintroduire SSN en clair
ALTER TABLE patients ADD COLUMN ssn VARCHAR(15);

-- Reconstituer ssn depuis ssn_encrypted (nécessite la clé)
DO $$
DECLARE
    v_key TEXT := COALESCE(current_setting('medassist.ssn_key', true), 'medassist_default_key');
BEGIN
    UPDATE patients
    SET ssn = pgp_sym_decrypt(ssn_encrypted::BYTEA, v_key)::TEXT;
END;
$$;

-- Restaurer l'index unique
CREATE UNIQUE INDEX IF NOT EXISTS idx_patients_ssn ON patients (ssn);

-- Recréer trigger de synchro
CREATE OR REPLACE FUNCTION sync_patient_ssn_encryption()
RETURNS TRIGGER AS $$
DECLARE
    v_key TEXT;
BEGIN
    v_key := COALESCE(current_setting('medassist.ssn_key', true), 'medassist_default_key');

    IF NEW.ssn IS NOT NULL THEN
        NEW.ssn_encrypted := pgp_sym_encrypt(NEW.ssn::TEXT, v_key);
        NEW.ssn_hash := digest(NEW.ssn::TEXT, 'sha256');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_patient_ssn_encryption ON patients;
CREATE TRIGGER trg_sync_patient_ssn_encryption
BEFORE INSERT OR UPDATE OF ssn ON patients
FOR EACH ROW
EXECUTE FUNCTION sync_patient_ssn_encryption();

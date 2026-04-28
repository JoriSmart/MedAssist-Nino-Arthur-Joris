-- =====================================================================
-- V15__evolution_D_expand.sql
-- Évolution D - Phase 1 : EXPAND
-- Ajout du chiffrement SSN (pgcrypto) avec coexistence des formats
-- =====================================================================

-- Extension pgcrypto (déjà présente en V1, mais sécuriser)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Ajouter colonnes chiffrées et hash
ALTER TABLE patients ADD COLUMN IF NOT EXISTS ssn_encrypted BYTEA;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS ssn_hash BYTEA;

-- Index de recherche/unique sur hash (pour V2)
CREATE UNIQUE INDEX IF NOT EXISTS idx_patients_ssn_hash ON patients (ssn_hash);

-- Trigger de synchronisation : ssn -> ssn_encrypted + ssn_hash
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

COMMENT ON COLUMN patients.ssn_encrypted IS 'SSN chiffré (pgcrypto, AES)';
COMMENT ON COLUMN patients.ssn_hash IS 'SHA-256 du SSN (unique, lookup)';

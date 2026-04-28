-- =====================================================================
-- V16__evolution_D_backfill.sql
-- Évolution D - Phase 2 : BACKFILL
-- Chiffrement des SSN existants
-- =====================================================================

DO $$
DECLARE
    v_key TEXT := COALESCE(current_setting('medassist.ssn_key', true), 'medassist_default_key');
    v_missing INT;
BEGIN
    UPDATE patients
    SET ssn_encrypted = pgp_sym_encrypt(ssn::TEXT, v_key),
        ssn_hash = digest(ssn::TEXT, 'sha256')
    WHERE ssn IS NOT NULL
      AND (ssn_encrypted IS NULL OR ssn_hash IS NULL);

    SELECT COUNT(*) INTO v_missing
    FROM patients
    WHERE ssn IS NOT NULL AND (ssn_encrypted IS NULL OR ssn_hash IS NULL);

    IF v_missing = 0 THEN
        RAISE NOTICE '✓ Backfill D OK: SSN chiffrés pour tous les patients';
    ELSE
        RAISE EXCEPTION '✗ Backfill D FAIL: % patients sans SSN chiffré', v_missing;
    END IF;
END;
$$;

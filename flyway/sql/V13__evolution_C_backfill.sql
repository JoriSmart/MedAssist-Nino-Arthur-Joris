-- =====================================================================
-- V13__evolution_C_backfill.sql
-- Évolution C - Phase 2 : BACKFILL
-- Migration des valeurs gender -> gender_code
-- =====================================================================

UPDATE patients
SET gender_code = CASE
    WHEN gender IN ('M', 'F') THEN gender
    ELSE 'U'
END
WHERE gender_code IS NULL;

-- Vérification
DO $$
DECLARE
    v_missing INT;
BEGIN
    SELECT COUNT(*) INTO v_missing
    FROM patients
    WHERE gender_code IS NULL;

    IF v_missing = 0 THEN
        RAISE NOTICE '✓ Backfill C OK: gender_code rempli pour tous les patients';
    ELSE
        RAISE EXCEPTION '✗ Backfill C FAIL: % patients sans gender_code', v_missing;
    END IF;
END;
$$;

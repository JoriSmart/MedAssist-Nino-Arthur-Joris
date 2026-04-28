-- =====================================================================
-- test_evolution_D.sql
-- Tests de validation pour Évolution D (SSN encryption)
-- =====================================================================

\echo '=== TEST ÉVOLUTION D : SSN encryption ==='

-- TEST 1 : SSN chiffré présent
DO $$
DECLARE
    v_missing INT;
BEGIN
    SELECT COUNT(*) INTO v_missing
    FROM patients
    WHERE ssn_encrypted IS NULL OR ssn_hash IS NULL;

    IF v_missing = 0 THEN
        RAISE NOTICE '✓ TEST 1 PASS: ssn_encrypted + ssn_hash présents';
    ELSE
        RAISE EXCEPTION '✗ TEST 1 FAIL: % patients sans chiffrement', v_missing;
    END IF;
END;
$$;

-- TEST 2 : Unicité hash
DO $$
DECLARE
    v_duplicates INT;
BEGIN
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT ssn_hash FROM patients
        GROUP BY ssn_hash
        HAVING COUNT(*) > 1
    ) t;

    IF v_duplicates = 0 THEN
        RAISE NOTICE '✓ TEST 2 PASS: ssn_hash unique';
    ELSE
        RAISE EXCEPTION '✗ TEST 2 FAIL: % doublons hash', v_duplicates;
    END IF;
END;
$$;

\echo '=== FIN TESTS ÉVOLUTION D ==='

-- =====================================================================
-- test_evolution_C.sql
-- Tests de validation pour Évolution C (Gender refactor)
-- =====================================================================

\echo '=== TEST ÉVOLUTION C : Gender refactor ==='

-- TEST 1 : Toutes les valeurs gender sont valides
DO $$
DECLARE
    v_invalid INT;
BEGIN
    SELECT COUNT(*) INTO v_invalid
    FROM patients
    WHERE gender NOT IN ('M', 'F', 'NB', 'U');

    IF v_invalid = 0 THEN
        RAISE NOTICE '✓ TEST 1 PASS: valeurs gender valides';
    ELSE
        RAISE EXCEPTION '✗ TEST 1 FAIL: % valeurs invalides', v_invalid;
    END IF;
END;
$$;

-- TEST 2 : FK gender_ref ok
DO $$
DECLARE
    v_missing INT;
BEGIN
    SELECT COUNT(*) INTO v_missing
    FROM patients p
    WHERE NOT EXISTS (SELECT 1 FROM gender_ref g WHERE g.code = p.gender);

    IF v_missing = 0 THEN
        RAISE NOTICE '✓ TEST 2 PASS: FK gender_ref OK';
    ELSE
        RAISE EXCEPTION '✗ TEST 2 FAIL: % lignes sans référence', v_missing;
    END IF;
END;
$$;

\echo '=== FIN TESTS ÉVOLUTION C ==='

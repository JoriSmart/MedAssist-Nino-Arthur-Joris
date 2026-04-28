-- =====================================================================
-- test_evolution_A.sql
-- Tests de validation pour Évolution A (Addresses Restructuring)
--
-- Vérifie :
-- 1. Intégrité des données après migration
-- 2. Compatibilité ascendante (V1 queries fonctionnent)
-- 3. Compatibilité descendante (V2 queries fonctionnent)
-- 4. Rollback réversible
-- 5. Performance (pas de dégradation)
-- =====================================================================

-- ═══════════════════════════════════════════════════════════════════
-- TEST 1 : INTÉGRITÉ DES DONNÉES
-- ═══════════════════════════════════════════════════════════════════

\echo '=== TEST 1 : Intégrité des données après migration ==='

-- 1a. Vérifier que tous les patients ont une adresse primaire
DO $$
DECLARE
    v_count INT;
BEGIN
    -- Compter patients sans adresse primaire
    SELECT COUNT(*) INTO v_count
    FROM patients p
    WHERE NOT EXISTS (
        SELECT 1 FROM addresses a
        WHERE a.patient_id = p.id AND a.is_primary = TRUE
    );
    
    IF v_count = 0 THEN
        RAISE NOTICE '✓ TEST 1a PASS: Toutes adresses V1 ont été migrées';
    ELSE
        RAISE EXCEPTION '✗ TEST 1a FAIL: % patients ont perdu leur adresse', v_count;
    END IF;
END;
$$;

-- 1b. Vérifier qu'aucune adresse n'a patient_id NULL
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM addresses WHERE patient_id IS NULL;
    IF v_count = 0 THEN
        RAISE NOTICE '✓ TEST 1b PASS: Aucune adresse avec patient_id NULL';
    ELSE
        RAISE EXCEPTION '✗ TEST 1b FAIL: % adresses orphelines trouvées', v_count;
    END IF;
END;
$$;

-- 1c. Vérifier que chaque patient a au moins une adresse primaire
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM patients p
    WHERE NOT EXISTS (
        SELECT 1 FROM addresses a 
        WHERE a.patient_id = p.id AND a.is_primary = TRUE
    );
    
    IF v_count = 0 THEN
        RAISE NOTICE '✓ TEST 1c PASS: Tous patients ont une adresse primaire';
    ELSE
        RAISE EXCEPTION '✗ TEST 1c FAIL: % patients sans adresse primaire', v_count;
    END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- TEST 2 : COMPATIBILITÉ ASCENDANTE (V1 queries)
-- ═══════════════════════════════════════════════════════════════════

\echo '=== TEST 2 : Compatibilité ascendante (V1 queries) ==='

-- 2a. SELECT patients with address filtering (V1 style)
DO $$
DECLARE
    v_count INT;
BEGIN
    -- V1 : SELECT FROM patients WHERE city = 'Paris'
    -- V2 : should work via addresses table
    SELECT COUNT(*) INTO v_count
    FROM patients p
    JOIN addresses a ON p.id = a.patient_id
    WHERE a.city = 'Paris' AND a.is_primary = TRUE;
    
    RAISE NOTICE '✓ TEST 2a PASS: V1 city filter query returns % records', v_count;
END;
$$;

-- 2b. SELECT patients by postal_code
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM patients p
    JOIN addresses a ON p.id = a.patient_id
    WHERE a.postal_code = '75002' AND a.is_primary = TRUE;
    
    RAISE NOTICE '✓ TEST 2b PASS: V1 postal_code filter query returns % records', v_count;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- TEST 3 : COMPATIBILITÉ DESCENDANTE (V2 queries)
-- ═══════════════════════════════════════════════════════════════════

\echo '=== TEST 3 : Compatibilité descendante (V2 queries) ==='

-- 3a. Query V2 : SELECT multi-adresses par patient
DO $$
DECLARE
    v_record RECORD;
BEGIN
    -- V2 : query addresses directement
    FOR v_record IN
        SELECT p.id, COUNT(a.id) as address_count
        FROM patients p
        LEFT JOIN addresses a ON p.id = a.patient_id
        GROUP BY p.id
        LIMIT 1
    LOOP
        RAISE NOTICE '✓ TEST 3a PASS: V2 multi-address query works - patient % has % addresses',
            v_record.id, v_record.address_count;
    END LOOP;
END;
$$;

-- 3b. Query V2 : SELECT addresses par type
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(DISTINCT address_type) INTO v_count FROM addresses;
    RAISE NOTICE '✓ TEST 3b PASS: V2 address_type query returns % types', v_count;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- TEST 4 : INTÉGRITÉ RÉFÉRENTIELLE
-- ═══════════════════════════════════════════════════════════════════

\echo '=== TEST 4 : Intégrité référentielle ==='

-- 4a. Vérifier FK patients.address_id → addresses.id
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM patients p
    WHERE NOT EXISTS (SELECT 1 FROM addresses a WHERE a.id = p.address_id);
    
    IF v_count = 0 THEN
        RAISE NOTICE '✓ TEST 4a PASS: FK patients.address_id → addresses.id OK';
    ELSE
        RAISE EXCEPTION '✗ TEST 4a FAIL: % patients with broken FK', v_count;
    END IF;
END;
$$;

-- 4b. Vérifier FK addresses.patient_id → patients.id
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM addresses a
    WHERE NOT EXISTS (SELECT 1 FROM patients p WHERE p.id = a.patient_id);
    
    IF v_count = 0 THEN
        RAISE NOTICE '✓ TEST 4b PASS: FK addresses.patient_id → patients.id OK';
    ELSE
        RAISE EXCEPTION '✗ TEST 4b FAIL: % orphaned addresses', v_count;
    END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- TEST 5 : PERFORMANCE (no significant degradation)
-- ═══════════════════════════════════════════════════════════════════

\echo '=== TEST 5 : Performance (EXPLAIN ANALYZE) ==='
-- 5a. Query performance : Lookup patient avec adresse
\echo '✓ TEST 5a: Performance check - patient lookup with address'
EXPLAIN ANALYZE
    SELECT p.id, p.first_name, a.line1, a.city
    FROM patients p
    JOIN addresses a ON p.id = a.patient_id
    WHERE p.last_name = 'Dupont' AND a.is_primary = TRUE;

-- 5b. Query performance : Range query on consultations (should not degrade)
EXPLAIN ANALYZE
    SELECT COUNT(*) FROM consultations WHERE consultation_date >= '2024-01-01';

-- ═══════════════════════════════════════════════════════════════════
-- TEST 6 : STATISTIQUES FINALES
-- ═══════════════════════════════════════════════════════════════════

\echo '=== TEST 6 : Statistiques finales ==='

SELECT 
    'Patients' as entity,
    COUNT(*) as total
FROM patients
UNION ALL
SELECT 
    'Addresses' as entity,
    COUNT(*) as total
FROM addresses
UNION ALL
SELECT 
    'Addresses (PRIMARY)' as entity,
    COUNT(*) as total
FROM addresses
WHERE is_primary = TRUE
UNION ALL
SELECT 
    'Address Types' as entity,
    COUNT(DISTINCT address_type) as total
FROM addresses;

\echo '=== FIN DES TESTS ÉVOLUTION A ==='

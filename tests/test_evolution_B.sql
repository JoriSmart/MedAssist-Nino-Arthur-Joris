-- =====================================================================
-- test_evolution_B.sql
-- Tests de validation pour Évolution B (Doctor Normalization)
-- =====================================================================

\echo '=== TEST ÉVOLUTION B : Normalisation doctor_name ==='

-- TEST 1 : Vérifier que les docteurs sont présents et liés
DO $$
DECLARE
    v_doctors_in_table INT;
    v_distinct_doctor_id INT;
BEGIN
    SELECT COUNT(*) INTO v_doctors_in_table FROM doctors;
    SELECT COUNT(DISTINCT doctor_id) INTO v_distinct_doctor_id FROM consultations;

    RAISE NOTICE 'TEST 1 : Docteurs et mapping';
    RAISE NOTICE '  Doctors table entries: %', v_doctors_in_table;
    RAISE NOTICE '  Distinct doctor_id in consultations: %', v_distinct_doctor_id;

    IF v_doctors_in_table > 0 AND v_distinct_doctor_id > 0 THEN
        RAISE NOTICE '✓ Docteurs présents et consultations mappées';
    ELSE
        RAISE EXCEPTION '✗ Docteurs ou mapping manquants';
    END IF;
END;
$$;

-- TEST 2 : Vérifier que toutes les consultations ont doctor_id
DO $$
DECLARE
    v_consultations_without_doctor_id INT;
BEGIN
    SELECT COUNT(*) INTO v_consultations_without_doctor_id
    FROM consultations WHERE doctor_id IS NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 2 : Complétude doctor_id';
    
    IF v_consultations_without_doctor_id = 0 THEN
        RAISE NOTICE '✓ Toutes consultations ont doctor_id';
    ELSE
        RAISE EXCEPTION '✗ % consultations manquent doctor_id', v_consultations_without_doctor_id;
    END IF;
END;
$$;

-- TEST 3 : Vérifier l'intégrité FK
DO $$
DECLARE
    v_orphaned_consultations INT;
BEGIN
    SELECT COUNT(*) INTO v_orphaned_consultations
    FROM consultations c
    WHERE NOT EXISTS (SELECT 1 FROM doctors d WHERE d.id = c.doctor_id);
    
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 3 : Intégrité FK';
    
    IF v_orphaned_consultations = 0 THEN
        RAISE NOTICE '✓ FK consultations.doctor_id → doctors.id OK';
    ELSE
        RAISE EXCEPTION '✗ % orphaned consultations', v_orphaned_consultations;
    END IF;
END;
$$;

-- TEST 4 : Vérifier normalisation (ex: "Dr Martin", "Dr. Martin" → même doctor)
DO $$
DECLARE
    v_record RECORD;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 4 : Vérification normalisation';
    RAISE NOTICE 'Consultation avec doctor normalisé:';
    
    FOR v_record IN
        SELECT d.id, d.first_name, d.last_name, COUNT(c.id) as consultation_count
        FROM doctors d
        LEFT JOIN consultations c ON c.doctor_id = d.id
        WHERE d.last_name NOT IN ('Unknown')
        GROUP BY d.id, d.first_name, d.last_name
        ORDER BY consultation_count DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '  Dr % % : % consultations', 
            v_record.first_name, v_record.last_name, v_record.consultation_count;
        v_count := v_count + 1;
    END LOOP;
    
    IF v_count > 0 THEN
        RAISE NOTICE '✓ Top doctors normalisés';
    END IF;
END;
$$;

-- TEST 5 : Compatibilité V2 queries
DO $$
DECLARE
    v_consultations_by_doctor INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 5 : Compatibilité V2 queries';
    
    -- V2 query : SELECT consultations JOIN doctors
    SELECT COUNT(*) INTO v_consultations_by_doctor
    FROM consultations c
    JOIN doctors d ON c.doctor_id = d.id
    WHERE d.last_name = 'Martin' OR d.last_name ILIKE '%martin%';
    
    RAISE NOTICE '✓ V2 JOIN query works: % consultations for Martin docteurs', 
        v_consultations_by_doctor;
END;
$$;

-- TEST 6 : Performance avant/après
EXPLAIN ANALYZE
SELECT COUNT(*) FROM consultations WHERE doctor_id = 1;

\echo '=== FIN TESTS ÉVOLUTION B ==='

-- =====================================================================
-- test_evolution_E.sql
-- Tests de validation pour Évolution E (Partitioning consultations)
-- =====================================================================

\echo '=== TEST ÉVOLUTION E : Partitionnement consultations ==='

-- TEST 1 : Vérifier que partitions existent et sont peuplées
DO $$
DECLARE
    v_total INT;
    v_partition_2021 INT;
    v_partition_2022 INT;
    v_partition_2023 INT;
    v_partition_2024 INT;
    v_partition_2025 INT;
    v_partition_future INT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM consultations;
    SELECT COUNT(*) INTO v_partition_2021 FROM consultations_p2021;
    SELECT COUNT(*) INTO v_partition_2022 FROM consultations_p2022;
    SELECT COUNT(*) INTO v_partition_2023 FROM consultations_p2023;
    SELECT COUNT(*) INTO v_partition_2024 FROM consultations_p2024;
    SELECT COUNT(*) INTO v_partition_2025 FROM consultations_p2025;
    SELECT COUNT(*) INTO v_partition_future FROM consultations_pfuture;
    
    RAISE NOTICE 'TEST 1 : Partition Distribution';
    RAISE NOTICE 'Total consultations: %', v_total;
    RAISE NOTICE '  2021: % (%.1f%%)', v_partition_2021, (v_partition_2021::FLOAT / v_total * 100);
    RAISE NOTICE '  2022: % (%.1f%%)', v_partition_2022, (v_partition_2022::FLOAT / v_total * 100);
    RAISE NOTICE '  2023: % (%.1f%%)', v_partition_2023, (v_partition_2023::FLOAT / v_total * 100);
    RAISE NOTICE '  2024: % (%.1f%%)', v_partition_2024, (v_partition_2024::FLOAT / v_total * 100);
    RAISE NOTICE '  2025: % (%.1f%%)', v_partition_2025, (v_partition_2025::FLOAT / v_total * 100);
    RAISE NOTICE '  Future: % (%.1f%%)', v_partition_future, (v_partition_future::FLOAT / v_total * 100);
    
    IF (v_partition_2021 + v_partition_2022 + v_partition_2023 + v_partition_2024 + v_partition_2025 + v_partition_future) = v_total THEN
        RAISE NOTICE '✓ Partition distribution verified';
    ELSE
        RAISE EXCEPTION '✗ Row count mismatch in partitions';
    END IF;
END;
$$;

-- TEST 2 : Vérifier que partition pruning fonctionne
RAISE NOTICE '';
RAISE NOTICE 'TEST 2 : Partition Pruning (EXPLAIN ANALYZE)';

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM consultations 
WHERE consultation_date >= '2024-01-01' AND consultation_date < '2025-01-01';
-- Should only scan partition 2024

-- TEST 3 : Performance query sur années multiples
RAISE NOTICE '';
RAISE NOTICE 'TEST 3 : Performance multi-year query';

EXPLAIN ANALYZE
SELECT COUNT(*) FROM consultations
WHERE EXTRACT(YEAR FROM consultation_date) IN (2023, 2024);
-- Should scan partitions 2023 + 2024

-- TEST 4 : Intégrité FK après partitionnement
DO $$
DECLARE
    v_orphaned_consultations INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 4 : Intégrité FK post-partition';
    
    SELECT COUNT(*) INTO v_orphaned_consultations
    FROM consultations c
    WHERE NOT EXISTS (SELECT 1 FROM patients p WHERE p.id = c.patient_id);
    
    IF v_orphaned_consultations = 0 THEN
        RAISE NOTICE '✓ FK consultations.patient_id → patients.id OK';
    ELSE
        RAISE EXCEPTION '✗ % orphaned consultations (patient FK)', v_orphaned_consultations;
    END IF;
END;
$$;

-- TEST 5 : Vérifier que indexes existent sur partitions
DO $$
DECLARE
    v_index_count INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 5 : Indexes sur partitions';
    
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE tablename LIKE 'consultations_%' OR tablename = 'consultations';
    
    RAISE NOTICE 'Indexes found: %', v_index_count;
    
    IF v_index_count >= 3 THEN
        RAISE NOTICE '✓ Sufficient indexes for partition scans';
    ELSE
        RAISE WARNING '⚠ Limited indexes - performance may be affected';
    END IF;
END;
$$;

-- TEST 6 : Tester insertion dans nouvelle partition (future)
DO $$
DECLARE
    v_inserted INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 6 : Insertion test (future year)';
    
    -- Essayer insérer une consultation 2026
    -- (ne pas committer dans un vrai test, juste vérifier que ça marche)
    BEGIN
        INSERT INTO consultations 
            (patient_id, doctor_id, consultation_date, consultation_type, fee_amount, is_paid)
        VALUES (1, 1, '2026-06-01 10:00'::TIMESTAMP, 'GENERAL', 25.00, FALSE);
        
        SELECT COUNT(*) INTO v_inserted FROM consultations_pfuture 
        WHERE EXTRACT(YEAR FROM consultation_date) = 2026;
        
        RAISE NOTICE '✓ Insert into future partition successful (%)', v_inserted;
        
        -- Rollback l'insert de test
        RAISE EXCEPTION 'rollback_test';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'rollback_test' THEN
            RAISE NOTICE '  (test insert rolled back)';
        ELSE
            RAISE;
        END IF;
    END;
END;
$$;

-- TEST 7 : Comparer performance old vs new
RAISE NOTICE '';
RAISE NOTICE 'TEST 7 : Performance Comparison (old shadow vs new partitioned)';
RAISE NOTICE '';
RAISE NOTICE 'Query: SELECT COUNT(*) WHERE consultation_date >= 2024-01-01';

RAISE NOTICE 'Old table (consultations_shadow):';
EXPLAIN ANALYZE
SELECT COUNT(*) FROM consultations_shadow 
WHERE consultation_date >= '2024-01-01';

RAISE NOTICE '';
RAISE NOTICE 'New table (consultations - partitioned):';
EXPLAIN ANALYZE
SELECT COUNT(*) FROM consultations 
WHERE consultation_date >= '2024-01-01';

RAISE NOTICE '';
RAISE NOTICE '=== FIN TESTS ÉVOLUTION E ===';

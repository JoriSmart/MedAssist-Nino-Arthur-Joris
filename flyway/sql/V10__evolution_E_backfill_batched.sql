-- =====================================================================
-- V9__evolution_E_backfill_batched.sql
-- Évolution E - Phase 2 : BACKFILL avec Batching
-- Copie des données de consultations vers consultations_v2 par batch
--
-- Stratégie : Batch insert (5M lignes/batch) pour éviter lock table entière
-- =====================================================================

-- Désactiver les contraintes FK temporairement (pour accélération)
-- Nota : On les réactive en V10
ALTER TABLE consultations_v2 DISABLE TRIGGER ALL;

-- Fonction pour insérer par batch
CREATE OR REPLACE FUNCTION backfill_consultations_batched(
    p_batch_size INT DEFAULT 5000000
) RETURNS TABLE (
    batch_number INT,
    rows_inserted INT,
    duration_ms INT
) AS $$
DECLARE
    v_batch INT := 0;
    v_total_rows INT := 0;
    v_inserted INT := 0;
    v_start_time TIMESTAMP;
    v_duration_ms INT;
    v_min_id BIGINT;
    v_max_id BIGINT;
BEGIN
    -- Compter total rows à copier
    SELECT COUNT(*) INTO v_total_rows FROM consultations;
    RAISE NOTICE 'Backfill consultations: % rows total', v_total_rows;
    
    -- Obtenir range d'IDs
    SELECT MIN(id), MAX(id) INTO v_min_id, v_max_id FROM consultations;
    
    v_batch := 0;
    WHILE v_min_id IS NOT NULL AND v_min_id <= v_max_id LOOP
        v_batch := v_batch + 1;
        v_start_time := CURRENT_TIMESTAMP;
        
        -- Insérer batch : 5M rows à la fois
        INSERT INTO consultations_v2 
            (id, patient_id, doctor_id, consultation_date, symptoms, diagnosis, 
             notes, consultation_type, fee_amount, fee_currency, is_paid, created_at)
        SELECT 
            id, patient_id, doctor_id, consultation_date, symptoms, diagnosis,
            notes, consultation_type, fee_amount, fee_currency, is_paid, created_at
        FROM consultations
        WHERE id >= v_min_id 
            AND id < (v_min_id + p_batch_size)
        ORDER BY id;
        
        GET DIAGNOSTICS v_inserted = ROW_COUNT;
        v_duration_ms := EXTRACT(MILLISECOND FROM (CURRENT_TIMESTAMP - v_start_time));
        
        RAISE NOTICE 'Batch %: % rows inserted in %ms', v_batch, v_inserted, v_duration_ms;
        
        batch_number := v_batch;
        rows_inserted := v_inserted;
        duration_ms := v_duration_ms;
        RETURN NEXT;
        
        -- Pause entre batches (pour éviter lock complet)
        PERFORM pg_sleep(0.5);
        
        v_min_id := v_min_id + p_batch_size;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Exécuter le backfill
SELECT * FROM backfill_consultations_batched(5000000);

-- Vérifier que tous les rows ont été copiés
DO $$
DECLARE
    v_original_count INT;
    v_copied_count INT;
BEGIN
    SELECT COUNT(*) INTO v_original_count FROM consultations;
    SELECT COUNT(*) INTO v_copied_count FROM consultations_v2;
    
    RAISE NOTICE 'Backfill E verification:';
    RAISE NOTICE '  - Original consultations: %', v_original_count;
    RAISE NOTICE '  - Copied to consultations_v2: %', v_copied_count;
    
    IF v_original_count = v_copied_count THEN
        RAISE NOTICE '✓ Backfill complete and verified';
    ELSE
        RAISE EXCEPTION '✗ Row count mismatch: % vs %', v_original_count, v_copied_count;
    END IF;
END;
$$;

-- Réactiver les triggers
ALTER TABLE consultations_v2 ENABLE TRIGGER ALL;

COMMENT ON FUNCTION backfill_consultations_batched(INT) IS
'Insère consultations par batch (5M lignes) vers consultations_v2
Évite lock table entière, permet pause entre batches
Duration : ~5-10h sur 18M lignes';

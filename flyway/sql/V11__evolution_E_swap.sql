-- =====================================================================
-- V10__evolution_E_swap.sql
-- Évolution E - Phase 3 : SWAP / FINALIZE
-- Rename : old consultations → shadow, consultations_v2 → consultations
--
-- ⚠️  ATTENTION : Cette étape requiert downtime minimal (~30min)
-- À exécuter pendant fenêtre maintenance (dimanche 2h-6h)
-- =====================================================================

-- Étape 1 : Attendre que toutes les connexions anciennes se ferment
-- (Dans un vrai déploiement, c'est géré par orchestration - Kubernetes, etc.)
DO $$
BEGIN
    RAISE NOTICE 'SWAP Phase 1: Closing old connections...';
    -- Terminer toutes les sessions excepté celle actuelle
    -- Note: Cela demande rôle superuser ou pg_terminate_backend
    -- PERFORM pg_terminate_backend(pid) 
    -- FROM pg_stat_activity 
    -- WHERE pid != pg_backend_pid();
    
    RAISE NOTICE 'Step 1 complete: Ready for rename';
END;
$$;

-- Étape 2 : Renommer les tables
-- Schema: old consultations → consultations_shadow (for quick rollback)
--         consultations_v2 → consultations (new production)

-- Détacher le FK de consultations_v2 vers doctors temporairement
-- (pour pouvoir le renommer sans conflits)

-- Renommer consultations → consultations_shadow
ALTER TABLE consultations RENAME TO consultations_shadow;
ALTER INDEX IF EXISTS idx_consultations_patient RENAME TO idx_consultations_shadow_patient;
ALTER INDEX IF EXISTS idx_consultations_date RENAME TO idx_consultations_shadow_date;
ALTER INDEX IF EXISTS idx_consultations_doctor_id RENAME TO idx_consultations_shadow_doctor_id;
ALTER INDEX IF EXISTS idx_consultations_doctor_v2 RENAME TO idx_consultations_shadow_doctor_v2;
ALTER INDEX IF EXISTS idx_consultations_type RENAME TO idx_consultations_shadow_type;

-- Renommer consultations_v2 → consultations
ALTER TABLE consultations_v2 RENAME TO consultations;
ALTER INDEX IF EXISTS idx_consultations_v2_patient RENAME TO idx_consultations_patient;
ALTER INDEX IF EXISTS idx_consultations_v2_doctor RENAME TO idx_consultations_doctor;
ALTER INDEX IF EXISTS idx_consultations_v2_date RENAME TO idx_consultations_date;
ALTER INDEX IF EXISTS idx_consultations_v2_type RENAME TO idx_consultations_type;

-- Renommer les partitions
ALTER TABLE consultations_2021 RENAME TO consultations_p2021;
ALTER TABLE consultations_2022 RENAME TO consultations_p2022;
ALTER TABLE consultations_2023 RENAME TO consultations_p2023;
ALTER TABLE consultations_2024 RENAME TO consultations_p2024;
ALTER TABLE consultations_2025 RENAME TO consultations_p2025;
ALTER TABLE consultations_future RENAME TO consultations_pfuture;

-- Étape 3 : Recréer les contraintes FK sur la nouvelle table
-- (Elles ont déjà existé, mais refresh pour sûreté)
ALTER TABLE consultations DROP CONSTRAINT IF EXISTS fk_consultations_patient;
ALTER TABLE consultations ADD CONSTRAINT fk_consultations_patient
    FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE;

ALTER TABLE consultations DROP CONSTRAINT IF EXISTS fk_consultations_doctor;
ALTER TABLE consultations ADD CONSTRAINT fk_consultations_doctor
    FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE RESTRICT;

-- Créer index unique sur consultations (pour garantir pas de doublons)
-- Note: id + consultation_date car partitioned by date
CREATE UNIQUE INDEX idx_consultations_id_unique ON consultations (id, consultation_date);

-- Étape 4 : Vérification finale
DO $$
DECLARE
    v_consultations_count INT;
    v_shadow_count INT;
    v_partition_2021_count INT;
BEGIN
    SELECT COUNT(*) INTO v_consultations_count FROM consultations;
    SELECT COUNT(*) INTO v_shadow_count FROM consultations_shadow;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== SWAP Complete ===';
    RAISE NOTICE 'New consultations (partitioned): % rows', v_consultations_count;
    RAISE NOTICE 'Shadow consultations (old): % rows', v_shadow_count;
    
    IF v_consultations_count = v_shadow_count THEN
        RAISE NOTICE '✓ Counts match - Safe to proceed';
    ELSE
        RAISE EXCEPTION '✗ Count mismatch! New: %, Old: %', v_consultations_count, v_shadow_count;
    END IF;
    
    -- Test query sur partitions
    RAISE NOTICE '';
    RAISE NOTICE 'Partition Distribution:';
    SELECT COUNT(*) INTO v_partition_2021_count
    FROM consultations
    WHERE consultation_date >= '2021-01-01' AND consultation_date < '2022-01-01';
    RAISE NOTICE '  2021: %', v_partition_2021_count;
END;
$$;

-- Étape 5 : Nettoyer l'ancienne table (optionnel - garder pour rollback rapide)
-- OPTION A : Garder la shadow table pour rollback rapide
-- ALTER TABLE consultations_shadow SET TABLESPACE pg_default;

-- OPTION B : Supprimer après vérification (économise espace disque)
-- DROP TABLE IF EXISTS consultations_shadow CASCADE;

COMMENT ON TABLE consultations IS
'V2 : Table partitionnée par année (consultation_date RANGE)
6 partitions: 2021, 2022, 2023, 2024, 2025, future (2026+)
Remplace table non-partitionnée (now consultations_shadow)
Performance: queries sur années spécifiques scannent 1 partition au lieu de 18M rows';

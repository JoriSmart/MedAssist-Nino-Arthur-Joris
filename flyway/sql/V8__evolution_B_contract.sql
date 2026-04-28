-- =====================================================================
-- V7__evolution_B_contract.sql
-- Évolution B - Phase 3 : CONTRACT
-- Suppression du champ doctor_name (maintenant dans doctors table)
--
-- Cette phase finalise la migration
-- =====================================================================

-- Supprimer le trigger de synchronisation
DROP TRIGGER IF EXISTS trg_sync_consultation_doctor_to_table ON consultations;
DROP FUNCTION IF EXISTS sync_consultation_doctor_to_table();
DROP FUNCTION IF EXISTS doctor_name_matches(VARCHAR, VARCHAR, VARCHAR);

-- Rendre doctor_id NOT NULL + Ajouter contrainte
ALTER TABLE consultations
    ALTER COLUMN doctor_id SET NOT NULL;

-- Supprimer la colonne doctor_name
ALTER TABLE consultations DROP COLUMN doctor_name;

-- Recréer index optimisé pour V2 queries
DROP INDEX IF EXISTS idx_consultations_doctor;
CREATE INDEX idx_consultations_doctor_v2 ON consultations (doctor_id, consultation_date);

-- Vérification finale
DO $$
DECLARE
    v_count INT;
    v_doctor_count INT;
BEGIN
    -- Vérifier qu'aucune consultation n'a doctor_id NULL
    SELECT COUNT(*) INTO v_count FROM consultations WHERE doctor_id IS NULL;
    IF v_count = 0 THEN
        RAISE NOTICE '✓ Contract B Phase 3 OK: consultations.doctor_id all NOT NULL';
    ELSE
        RAISE EXCEPTION '✗ ERROR: % consultations avec doctor_id NULL', v_count;
    END IF;
    
    -- Vérifier qu'aucune consultation ne référence un doctor inexistant
    SELECT COUNT(*) INTO v_count
    FROM consultations c
    WHERE NOT EXISTS (SELECT 1 FROM doctors d WHERE d.id = c.doctor_id);
    
    IF v_count = 0 THEN
        RAISE NOTICE '✓ FK integrity OK: tous doctor_id pointent vers doctors';
    ELSE
        RAISE EXCEPTION '✗ ERROR: % broken FKs', v_count;
    END IF;
    
    -- Vérifier que ~120 doctors existent
    SELECT COUNT(*) INTO v_doctor_count FROM doctors;
    RAISE NOTICE 'Total doctors: %', v_doctor_count;
END;
$$;

COMMENT ON TABLE consultations IS 
'V2 : doctor_id FK remplace doctor_name VARCHAR
Réduction de 18M lignes × 200 bytes (doctor_name) → 8 bytes (doctor_id)
Performance amélioration sur JOINs avec doctors table';

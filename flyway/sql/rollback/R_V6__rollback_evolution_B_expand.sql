-- =====================================================================
-- R_V6__rollback_evolution_B_expand.sql
-- Rollback Évolution B - Phase 1 (EXPAND)
-- =====================================================================

-- Supprimer trigger et fonctions
DROP TRIGGER IF EXISTS trg_sync_consultation_doctor_to_table ON consultations;
DROP FUNCTION IF EXISTS sync_consultation_doctor_to_table();
DROP FUNCTION IF EXISTS doctor_name_matches(VARCHAR, VARCHAR, VARCHAR);

-- Supprimer colonne doctor_id et FK
ALTER TABLE consultations DROP CONSTRAINT IF EXISTS fk_consultations_doctor;
ALTER TABLE consultations DROP COLUMN IF EXISTS doctor_id;

-- Supprimer indexes
DROP INDEX IF EXISTS idx_consultations_doctor_id;
DROP INDEX IF EXISTS idx_doctors_name;
DROP INDEX IF EXISTS idx_doctors_rpps;
DROP INDEX IF EXISTS idx_doctors_specialty;

-- Supprimer table doctors
DROP TABLE IF EXISTS doctors;

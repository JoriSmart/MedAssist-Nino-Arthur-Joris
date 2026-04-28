-- =====================================================================
-- R_V7__rollback_evolution_B_backfill.sql
-- Rollback Évolution B - Phase 2 (BACKFILL)
-- =====================================================================

-- Remettre consultations.doctor_id à NULL
UPDATE consultations SET doctor_id = NULL;

-- Supprimer les doctors créés
DELETE FROM doctors;

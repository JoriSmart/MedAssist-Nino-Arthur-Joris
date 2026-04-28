-- =====================================================================
-- R_V13__rollback_evolution_C_backfill.sql
-- Rollback Évolution C - Phase 2 (BACKFILL)
-- =====================================================================

UPDATE patients SET gender_code = NULL;

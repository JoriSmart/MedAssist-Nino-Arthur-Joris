-- =====================================================================
-- R_V16__rollback_evolution_D_backfill.sql
-- Rollback Évolution D - Phase 2 (BACKFILL)
-- =====================================================================

UPDATE patients SET ssn_encrypted = NULL, ssn_hash = NULL;

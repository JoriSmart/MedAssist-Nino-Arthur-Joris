-- =====================================================================
-- R_V10__rollback_evolution_E_backfill_batched.sql
-- Rollback Évolution E - Phase 2 (BACKFILL)
-- =====================================================================

-- Supprimer la fonction de backfill
DROP FUNCTION IF EXISTS backfill_consultations_batched(INT);

-- Nettoyer la table de destination
TRUNCATE TABLE IF EXISTS consultations_v2;

-- Réactiver les triggers (sécurité)
ALTER TABLE consultations_v2 ENABLE TRIGGER ALL;

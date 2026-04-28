-- =====================================================================
-- R_V2__rollback_evolution_A_expand.sql
-- Rollback de V2 : suppression de addresses + trigger + vue
--
-- Reversal: Supprime tout ce qui a été créé en V2
-- =====================================================================

-- Supprimer la vue de compatibilité
DROP VIEW IF EXISTS v_patients_with_address;

-- Supprimer le trigger
DROP TRIGGER IF EXISTS trg_sync_patient_address_to_table ON patients;
DROP FUNCTION IF EXISTS sync_patient_address_to_table();

-- Supprimer la colonne temporaire address_id
ALTER TABLE patients DROP COLUMN IF EXISTS address_id;

-- Supprimer les index
DROP INDEX IF EXISTS idx_addresses_patient;
DROP INDEX IF EXISTS idx_addresses_type;
DROP INDEX IF EXISTS idx_addresses_primary;

-- Supprimer la table addresses
DROP TABLE IF EXISTS addresses CASCADE;

COMMENT ON TABLE patients IS 'Rollback V2 complete - addresses table removed, patients.address_id removed';

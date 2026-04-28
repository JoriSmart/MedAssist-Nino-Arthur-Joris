-- =====================================================================
-- V17__evolution_D_contract.sql
-- Évolution D - Phase 3 : CONTRACT
-- Suppression du SSN en clair, maintien du hash et du chiffré
-- =====================================================================

-- Supprimer le trigger de synchro
DROP TRIGGER IF EXISTS trg_sync_patient_ssn_encryption ON patients;
DROP FUNCTION IF EXISTS sync_patient_ssn_encryption();

-- Rendre les colonnes V2 NOT NULL
ALTER TABLE patients
    ALTER COLUMN ssn_encrypted SET NOT NULL,
    ALTER COLUMN ssn_hash SET NOT NULL;

-- Supprimer l'index V1 sur SSN clair
DROP INDEX IF EXISTS idx_patients_ssn;

-- Supprimer la colonne SSN en clair
ALTER TABLE patients DROP COLUMN ssn;

COMMENT ON TABLE patients IS
'V2 : SSN chiffré (ssn_encrypted) + hash (ssn_hash). SSN en clair supprimé.';

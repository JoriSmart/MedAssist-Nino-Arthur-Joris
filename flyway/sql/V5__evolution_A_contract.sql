-- =====================================================================
-- V4__evolution_A_contract.sql
-- Évolution A - Phase 3 : CONTRACT
-- Suppression des colonnes address_* (maintenant dans addresses table)
--
-- Cette phase finalise la migration en supprimant l'ancienne structure
-- =====================================================================

-- Supprimer le trigger de synchronisation (plus besoin après migration)
DROP TRIGGER IF EXISTS trg_sync_patient_address_to_table ON patients;
DROP FUNCTION IF EXISTS sync_patient_address_to_table();

-- Supprimer la vue de compatibilité V1 (plus besoin - V2 utilise addresses directement)
DROP VIEW IF EXISTS v_patients_with_address;

-- Supprimer les colonnes address_* de patients (données maintenant dans addresses)
ALTER TABLE patients 
    DROP COLUMN address_line1,
    DROP COLUMN address_line2,
    DROP COLUMN city,
    DROP COLUMN postal_code;

-- Nettoyer les index obsolètes (si existants)
DROP INDEX IF EXISTS idx_patients_name;  -- À recréer si pertinent
-- Note : idx_patients_ssn keep (utile pour lookups patients)

-- Finaliser address_id : convertir en NOT NULL + ajouter FK constraint
ALTER TABLE patients
    ALTER COLUMN address_id SET NOT NULL,
    ADD CONSTRAINT fk_patients_primary_address 
        FOREIGN KEY (address_id) 
        REFERENCES addresses(id) ON DELETE RESTRICT;

-- Créer index sur patients.address_id pour perf JOINs
CREATE INDEX idx_patients_address_id ON patients (address_id);

-- Vérification finale
DO $$
BEGIN
    -- Vérifier qu'aucune patient n'a address_id NULL
    IF EXISTS (SELECT 1 FROM patients WHERE address_id IS NULL) THEN
        RAISE EXCEPTION 'Erreur : patients avec address_id NULL après migration';
    END IF;
    
    -- Vérifier contrainte FK
    IF EXISTS (
        SELECT 1 FROM patients p
        WHERE NOT EXISTS (SELECT 1 FROM addresses a WHERE a.id = p.address_id)
    ) THEN
        RAISE EXCEPTION 'Erreur : Foreign Key violation - patients.address_id → addresses.id';
    END IF;
    
    RAISE NOTICE 'Contract OK : colonnes address_* supprimées, FK established';
END;
$$;

COMMENT ON COLUMN patients.address_id IS 
'FK vers addresses.id (adresse primaire du patient). 
V1 : address_* stored in patients
V2 : address moved to addresses table with address_type/is_primary support';

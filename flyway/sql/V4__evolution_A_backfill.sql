-- =====================================================================
-- V3__evolution_A_backfill.sql
-- Évolution A - Phase 2 : BACKFILL
-- Migration des adresses de patients.address_* vers table addresses
--
-- Cette phase popule la table addresses avec les données existantes
-- =====================================================================

-- Backfill : insérer les adresses existantes dans la nouvelle table
-- Pour chaque patient ayant une adresse_line1, créer une entrée 'HOME' (primaire)
INSERT INTO addresses (patient_id, address_type, line1, line2, city, postal_code, country, is_primary, created_at)
SELECT 
    p.id,
    'HOME' as address_type,
    COALESCE(p.address_line1, 'Unknown') as line1,
    p.address_line2 as line2,
    COALESCE(p.city, 'Unknown') as city,
    COALESCE(p.postal_code, '00000') as postal_code,
    'France' as country,
    TRUE as is_primary,
    p.created_at
FROM patients p
WHERE p.address_line1 IS NOT NULL OR p.city IS NOT NULL
    ON CONFLICT DO NOTHING;  -- Évite doublons si script reroulé

-- Mettre à jour address_id dans patients (référence à l'adresse primaire)
UPDATE patients p SET
    address_id = (
        SELECT id FROM addresses a 
        WHERE a.patient_id = p.id AND a.address_type = 'HOME' AND a.is_primary = TRUE
        LIMIT 1
    )
WHERE address_id IS NULL;

-- Créer une adresse par défaut pour les patients sans adresse (évite address_id NULL)
INSERT INTO addresses (patient_id, address_type, line1, line2, city, postal_code, country, is_primary, created_at)
SELECT 
    p.id,
    'HOME' as address_type,
    'Unknown' as line1,
    NULL as line2,
    'Unknown' as city,
    '00000' as postal_code,
    'France' as country,
    TRUE as is_primary,
    p.created_at
FROM patients p
WHERE p.address_id IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM addresses a WHERE a.patient_id = p.id AND a.address_type = 'HOME'
  );

-- Recalcule address_id pour ceux qui viennent d'être complétés
UPDATE patients p SET
    address_id = (
        SELECT id FROM addresses a 
        WHERE a.patient_id = p.id AND a.address_type = 'HOME' AND a.is_primary = TRUE
        LIMIT 1
    )
WHERE address_id IS NULL;

-- Vérification de l'intégrité
DO $$
DECLARE
    v_patients_without_addr INT;
    v_addresses_inserted INT;
BEGIN
    -- Compter patients qui avaient une adresse dans V1 mais pas d'entrée dans addresses
    SELECT COUNT(*) INTO v_patients_without_addr
    FROM patients p
    WHERE (p.address_line1 IS NOT NULL OR p.city IS NOT NULL)
        AND NOT EXISTS (SELECT 1 FROM addresses a WHERE a.patient_id = p.id);
    
    IF v_patients_without_addr > 0 THEN
        RAISE EXCEPTION 'Erreur backfill : % patients n''ont pas d''adresse migrée', v_patients_without_addr;
    END IF;
    
    SELECT COUNT(*) INTO v_addresses_inserted FROM addresses;
    RAISE NOTICE 'Backfill OK : % adresses insérées', v_addresses_inserted;
END;
$$;

COMMENT ON TABLE addresses IS 
'Backfill complété : toutes les adresses V1 ont été migrées vers addresses table';

-- =====================================================================
-- V2__evolution_A_expand.sql
-- Évolution A - Phase 1 : EXPAND
-- Création de la table addresses (1-N with patients)
-- 
-- Stratégie : Expand-Contract
-- Cette phase crée la nouvelle structure sans affecter l'ancienne
-- 
-- =====================================================================

-- Créer la table addresses avec la structure cible
CREATE TABLE addresses (
    id BIGSERIAL PRIMARY KEY,
    patient_id BIGINT NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    address_type VARCHAR(20) NOT NULL CHECK (address_type IN ('HOME', 'WORK', 'BILLING')),
    line1 VARCHAR(255) NOT NULL,
    line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    postal_code VARCHAR(10) NOT NULL,
    country VARCHAR(100) NOT NULL DEFAULT 'France',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index pour performances de requêtes courantes
CREATE INDEX idx_addresses_patient ON addresses (patient_id);
CREATE INDEX idx_addresses_type ON addresses (address_type);
CREATE INDEX idx_addresses_primary ON addresses (patient_id, is_primary) 
    WHERE is_primary = TRUE;

-- Ajouter colonne temporary address_id dans patients (will be FK)
ALTER TABLE patients ADD COLUMN address_id BIGINT;

-- Trigger de synchronisation V1→V2 (pendant transition)
-- Quand on UPDATE patients.address_line1, crée/update adresse dans addresses
CREATE OR REPLACE FUNCTION sync_patient_address_to_table()
RETURNS TRIGGER AS $$
BEGIN
    -- Si l'adresse a changé, créer une nouvelle adresse 'HOME' si elle existe
    IF (NEW.address_line1 IS NOT NULL) THEN
        -- Chercher si une adresse 'HOME' existe
        IF EXISTS (SELECT 1 FROM addresses WHERE patient_id = NEW.id AND address_type = 'HOME') THEN
            -- Mettre à jour l'adresse existante
            UPDATE addresses SET 
                line1 = NEW.address_line1,
                line2 = NEW.address_line2,
                city = COALESCE(NEW.city, 'Unknown'),
                postal_code = COALESCE(NEW.postal_code, '00000'),
                updated_at = CURRENT_TIMESTAMP
            WHERE patient_id = NEW.id AND address_type = 'HOME';
        ELSE
            -- Créer une nouvelle adresse 'HOME'
            INSERT INTO addresses (patient_id, address_type, line1, line2, city, postal_code, is_primary)
            VALUES (
                NEW.id,
                'HOME',
                NEW.address_line1,
                NEW.address_line2,
                COALESCE(NEW.city, 'Unknown'),
                COALESCE(NEW.postal_code, '00000'),
                TRUE
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_patient_address_to_table
AFTER UPDATE OF address_line1, address_line2, city, postal_code ON patients
FOR EACH ROW
EXECUTE FUNCTION sync_patient_address_to_table();

-- Vue de compatibilité V1 (SELECT uniquement pour l'instant)
-- Permet aux requêtes V1 de continuer fonctionner
CREATE OR REPLACE VIEW v_patients_with_address AS
SELECT 
    p.id,
    p.first_name,
    p.last_name,
    p.birth_date,
    p.gender,
    p.ssn,
    p.phone,
    p.email,
    -- Adresse : provient de addresses si existante, sinon colonnes old
    COALESCE(a.line1, p.address_line1) as address_line1,
    COALESCE(a.line2, p.address_line2) as address_line2,
    COALESCE(a.city, p.city) as city,
    COALESCE(a.postal_code, p.postal_code) as postal_code,
    p.created_at,
    p.updated_at
FROM patients p
LEFT JOIN addresses a ON p.id = a.patient_id AND a.address_type = 'HOME' AND a.is_primary = TRUE;

COMMENT ON TABLE addresses IS 
'Table addresses pour support multi-adresses (HOME, WORK, BILLING)
Réplaces les colonnes address_line1, address_line2, city, postal_code dans patients';

COMMENT ON FUNCTION sync_patient_address_to_table() IS 
'Trigger de synchronisation V1→V2: maintient addresses à jour quand patients.address_* change
Permet coexistence V1/V2 pendant migration';

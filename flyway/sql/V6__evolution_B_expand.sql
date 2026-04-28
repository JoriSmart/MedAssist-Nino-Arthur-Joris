-- =====================================================================
-- V5__evolution_B_expand.sql
-- Évolution B - Phase 1 : EXPAND
-- Création de la table doctors + colonne doctor_id dans consultations
--
-- Stratégie : Expand-Contract + Déduplication
-- =====================================================================

-- Créer la table doctors (référence centralisée)
CREATE TABLE doctors (
    id BIGSERIAL PRIMARY KEY,
    rpps_number VARCHAR(11) UNIQUE NOT NULL,  -- N° RPPS (identifiant national)
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    specialty VARCHAR(100),
    email VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_doctors_name ON doctors (last_name, first_name);
CREATE INDEX idx_doctors_rpps ON doctors (rpps_number);
CREATE INDEX idx_doctors_specialty ON doctors (specialty);

-- Ajouter colonne doctor_id dans consultations
ALTER TABLE consultations ADD COLUMN doctor_id BIGINT;
ALTER TABLE consultations ADD CONSTRAINT fk_consultations_doctor
    FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE RESTRICT;

-- Index pour performances
CREATE INDEX idx_consultations_doctor_id ON consultations (doctor_id);

-- Trigger de synchronisation V1→V2 (pendant transition)
-- Quand doctor_name est modifié, cherche/crée le doctor dans doctors table
CREATE OR REPLACE FUNCTION sync_consultation_doctor_to_table()
RETURNS TRIGGER AS $$
DECLARE
    v_doctor_id BIGINT;
    v_normalized_name TEXT;
BEGIN
    -- Normaliser le doctor_name
    -- Format cible : "Dr. FirstName LastName"
    v_normalized_name := TRIM(
        REPLACE(REPLACE(REPLACE(NEW.doctor_name, 'Dr.', 'Dr'), 'DR', 'Dr'), 'dr', 'Dr')
    );
    
    -- Chercher si ce docteur existe déjà
    SELECT id INTO v_doctor_id FROM doctors
    WHERE doctor_name_matches(NEW.doctor_name, last_name, first_name)
    LIMIT 1;
    
    -- Si pas trouvé, créer une entrée temporaire (sera finalisée en V6)
    IF v_doctor_id IS NULL THEN
        INSERT INTO doctors (rpps_number, first_name, last_name)
        VALUES (
            'TEMP-' || MD5(NEW.doctor_name)::text,  -- RPPS temp (sera updateé)
            'Unknown',
            TRIM(NEW.doctor_name)  -- Store full name as lastname temporairement
        )
        RETURNING id INTO v_doctor_id;
    END IF;
    
    NEW.doctor_id := v_doctor_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Helper function pour matcher doctor_name avec (first_name, last_name)
CREATE OR REPLACE FUNCTION doctor_name_matches(
    p_doctor_name VARCHAR,
    p_last_name VARCHAR,
    p_first_name VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
    -- Simple matching : si last_name ou first_name sont dans doctor_name
    RETURN (
        (p_last_name IS NOT NULL AND p_doctor_name ILIKE '%' || p_last_name || '%') OR
        (p_first_name IS NOT NULL AND p_doctor_name ILIKE '%' || p_first_name || '%')
    );
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_consultation_doctor_to_table
BEFORE INSERT ON consultations
FOR EACH ROW
WHEN (NEW.doctor_name IS NOT NULL)
EXECUTE FUNCTION sync_consultation_doctor_to_table();

COMMENT ON TABLE doctors IS 
'Référence centralisée des docteurs avec RPPS national
Remplace les VARCHAR doctor_name incohérents de consultations
Contient ~120 docteurs uniques dédupliqués';

COMMENT ON FUNCTION doctor_name_matches(VARCHAR, VARCHAR, VARCHAR) IS
'Helper function pour matcher doctor_name string avec (first_name, last_name)
Utilisé par trigger de synchronisation V1→V2';

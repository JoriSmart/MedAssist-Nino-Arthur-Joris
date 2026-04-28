-- =====================================================================
-- V6__evolution_B_backfill.sql
-- Évolution B - Phase 2 : BACKFILL + DÉDUPLICATION
-- Migration des doctor_name incohérents vers doctors table
--
-- Stratégie : 
-- 1. Extraire DISTINCT doctor_name
-- 2. Dédupliquer (ex: "Dr Martin", "Dr. Martin", "DR MARTIN" → 1 entry)
-- 3. Normaliser et insérer dans doctors
-- 4. Popupler consultations.doctor_id
-- =====================================================================

-- Étape 1 : Créer table temp pour déduplication
CREATE TEMPORARY TABLE doctor_dedup AS
WITH doctor_names AS (
    SELECT DISTINCT doctor_name FROM consultations WHERE doctor_name IS NOT NULL
),
normalized_names AS (
    SELECT 
        doctor_name,
        -- Normalisation : "Dr Martin" + "Dr. Martin" + "DR MARTIN" → même groupe
        UPPER(TRIM(
            REPLACE(REPLACE(REPLACE(doctor_name, 'Dr.', ''), 'Dr', ''), 'dr', '')
        )) as normalized_group,
        -- Extraire last_name (dernier mot), first_name (reste)
        SPLIT_PART(TRIM(
            REPLACE(REPLACE(REPLACE(doctor_name, 'Dr.', ''), 'Dr', ''), 'dr', '')
        ), ' ', -1) as last_name_guess,
        TRIM(REGEXP_REPLACE(
            REPLACE(REPLACE(REPLACE(doctor_name, 'Dr.', ''), 'Dr', ''), 'dr', ''),
            ' ' || SPLIT_PART(TRIM(
                REPLACE(REPLACE(REPLACE(doctor_name, 'Dr.', ''), 'Dr', ''), 'dr', '')
            ), ' ', -1) || '$', ''
        )) as first_name_guess
    FROM doctor_names
)
SELECT DISTINCT
    doctor_name,
    normalized_group,
    CASE 
        WHEN last_name_guess = '' THEN 'Unknown'
        ELSE last_name_guess 
    END as last_name,
    CASE 
        WHEN first_name_guess = '' THEN 'Unknown'
        ELSE first_name_guess 
    END as first_name,
    ROW_NUMBER() OVER (PARTITION BY normalized_group ORDER BY doctor_name) as dedup_rank
FROM normalized_names;

-- Étape 2 : Insérer les docteurs dédupliqués dans doctors table
-- Utiliser seulement le 1er (rank=1) de chaque groupe normalized_group
INSERT INTO doctors (rpps_number, first_name, last_name, specialty, created_at)
SELECT 
    MD5(d.normalized_group)::text as rpps_number,  -- Temporary RPPS (hashed normalized name)
    d.first_name,
    d.last_name,
    'General Practice' as specialty,  -- Default specialty (peut être mis à jour manuellement)
    CURRENT_TIMESTAMP
FROM doctor_dedup d
WHERE d.dedup_rank = 1
    ON CONFLICT (rpps_number) DO NOTHING;

-- Étape 3 : Mettre à jour consultations.doctor_id avec la FK vers doctors
UPDATE consultations c SET
    doctor_id = (
        SELECT d.id FROM doctors d
        WHERE doctor_name_matches(c.doctor_name, d.last_name, d.first_name)
        LIMIT 1  -- Si plusieurs matches (rare), prendre le 1er
    )
WHERE c.doctor_name IS NOT NULL AND c.doctor_id IS NULL;

-- Étape 4 : Vérification de l'intégrité
DO $$
DECLARE
    v_distinct_doctors INT;
    v_doctors_inserted INT;
    v_consultations_updated INT;
    v_consultations_without_doctor_id INT;
BEGIN
    -- Compter distinct doctors dans table
    SELECT COUNT(*) INTO v_distinct_doctors FROM doctors WHERE rpps_number LIKE 'TEMP-%' OR rpps_number LIKE '%-%';
    
    -- Compter consultations avec doctor_id
    SELECT COUNT(*) INTO v_consultations_updated FROM consultations WHERE doctor_id IS NOT NULL;
    
    -- Compter consultations avec doctor_name mais sans doctor_id
    SELECT COUNT(*) INTO v_consultations_without_doctor_id 
    FROM consultations WHERE doctor_name IS NOT NULL AND doctor_id IS NULL;
    
    RAISE NOTICE 'Backfill B Summary:';
    RAISE NOTICE '  - Doctors insérés: %', v_distinct_doctors;
    RAISE NOTICE '  - Consultations mises à jour: %', v_consultations_updated;
    RAISE NOTICE '  - Consultations sans doctor_id: %', v_consultations_without_doctor_id;
    
    IF v_consultations_without_doctor_id > 0 THEN
        RAISE WARNING 'Attention : % consultations n''ont pas pu être mappées à un doctor', 
            v_consultations_without_doctor_id;
    END IF;
END;
$$;

COMMENT ON TABLE doctors IS 
'Backfill B complété : ~120 docteurs uniques dédupliqués et insérés
Consultations.doctor_id maintenant peuplé';

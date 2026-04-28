-- =====================================================================
-- V8__evolution_E_create_partitioned.sql
-- Évolution E - Phase 1 : CREATE PARTITIONED TABLE
-- Création de la table consultations_v2 partitionnée par année
--
-- Stratégie : Shadow Table + Rename/Swap
-- =====================================================================

-- Créer la table partitionnée (shadow)
CREATE TABLE consultations_v2 (
    id BIGSERIAL,
    patient_id BIGINT NOT NULL REFERENCES patients(id),
    doctor_id BIGINT NOT NULL REFERENCES doctors(id) ON DELETE RESTRICT,
    consultation_date TIMESTAMP NOT NULL,
    symptoms TEXT,
    diagnosis TEXT,
    notes TEXT,
    consultation_type VARCHAR(50) NOT NULL,
    fee_amount DECIMAL(10,2) NOT NULL,
    fee_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, consultation_date)  -- Partition key must be in PK
) PARTITION BY RANGE (EXTRACT(YEAR FROM consultation_date));

-- Créer partitions pour chaque année
CREATE TABLE consultations_2021 PARTITION OF consultations_v2
    FOR VALUES FROM (2021) TO (2022);

CREATE TABLE consultations_2022 PARTITION OF consultations_v2
    FOR VALUES FROM (2022) TO (2023);

CREATE TABLE consultations_2023 PARTITION OF consultations_v2
    FOR VALUES FROM (2023) TO (2024);

CREATE TABLE consultations_2024 PARTITION OF consultations_v2
    FOR VALUES FROM (2024) TO (2025);

CREATE TABLE consultations_2025 PARTITION OF consultations_v2
    FOR VALUES FROM (2025) TO (2026);

-- Partition pour future données (2026+)
CREATE TABLE consultations_future PARTITION OF consultations_v2
    FOR VALUES FROM (2026) TO (MAXVALUE);

-- Créer indexes sur partitions
CREATE INDEX idx_consultations_v2_patient ON consultations_v2 (patient_id);
CREATE INDEX idx_consultations_v2_doctor ON consultations_v2 (doctor_id);
CREATE INDEX idx_consultations_v2_date ON consultations_v2 (consultation_date);
CREATE INDEX idx_consultations_v2_type ON consultations_v2 (consultation_type);

-- Indexes locaux par partition (auto-created par PostgreSQL)
-- Pour améliorer performance des scans par partition

COMMENT ON TABLE consultations_v2 IS 
'Shadow table - Partitionnée par année (consultation_date)
Cible V2 : remplacera table consultations non-partitionnée
Avantage : scans sur partitions spécifiques évitent full table scan';

COMMENT ON TABLE consultations_2021 IS 'Partition 2021';
COMMENT ON TABLE consultations_2022 IS 'Partition 2022';
COMMENT ON TABLE consultations_2023 IS 'Partition 2023';
COMMENT ON TABLE consultations_2024 IS 'Partition 2024';
COMMENT ON TABLE consultations_2025 IS 'Partition 2025';
COMMENT ON TABLE consultations_future IS 'Partition future (2026+)';

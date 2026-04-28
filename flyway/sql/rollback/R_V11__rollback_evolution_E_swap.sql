-- =====================================================================
-- R_V11__rollback_evolution_E_swap.sql
-- Rollback Évolution E - Phase 3 (SWAP)
-- =====================================================================

-- Renommer consultations (partitioned) vers consultations_v2
ALTER TABLE consultations RENAME TO consultations_v2;
ALTER INDEX IF EXISTS idx_consultations_patient RENAME TO idx_consultations_v2_patient;
ALTER INDEX IF EXISTS idx_consultations_doctor RENAME TO idx_consultations_v2_doctor;
ALTER INDEX IF EXISTS idx_consultations_date RENAME TO idx_consultations_v2_date;
ALTER INDEX IF EXISTS idx_consultations_type RENAME TO idx_consultations_v2_type;

-- Renommer shadow vers consultations
ALTER TABLE consultations_shadow RENAME TO consultations;
ALTER INDEX IF EXISTS idx_consultations_shadow_patient RENAME TO idx_consultations_patient;
ALTER INDEX IF EXISTS idx_consultations_shadow_date RENAME TO idx_consultations_date;
ALTER INDEX IF EXISTS idx_consultations_shadow_doctor_id RENAME TO idx_consultations_doctor_id;
ALTER INDEX IF EXISTS idx_consultations_shadow_doctor_v2 RENAME TO idx_consultations_doctor_v2;
ALTER INDEX IF EXISTS idx_consultations_shadow_type RENAME TO idx_consultations_type;

-- Renommer les partitions (retour)
ALTER TABLE IF EXISTS consultations_p2021 RENAME TO consultations_2021;
ALTER TABLE IF EXISTS consultations_p2022 RENAME TO consultations_2022;
ALTER TABLE IF EXISTS consultations_p2023 RENAME TO consultations_2023;
ALTER TABLE IF EXISTS consultations_p2024 RENAME TO consultations_2024;
ALTER TABLE IF EXISTS consultations_p2025 RENAME TO consultations_2025;
ALTER TABLE IF EXISTS consultations_pfuture RENAME TO consultations_future;

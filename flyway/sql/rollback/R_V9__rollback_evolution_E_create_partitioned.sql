-- =====================================================================
-- R_V9__rollback_evolution_E_create_partitioned.sql
-- Rollback Évolution E - Phase 1 (CREATE PARTITIONED)
-- =====================================================================

-- Supprimer table partitionnée et partitions
DROP TABLE IF EXISTS consultations_v2 CASCADE;
DROP TABLE IF EXISTS consultations_2021 CASCADE;
DROP TABLE IF EXISTS consultations_2022 CASCADE;
DROP TABLE IF EXISTS consultations_2023 CASCADE;
DROP TABLE IF EXISTS consultations_2024 CASCADE;
DROP TABLE IF EXISTS consultations_2025 CASCADE;
DROP TABLE IF EXISTS consultations_future CASCADE;

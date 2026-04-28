-- V1__init_schema.sql : Création du schéma initial
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE patients (
    id           BIGSERIAL    PRIMARY KEY,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    birth_date   DATE         NOT NULL,
    gender       CHAR(1)      NOT NULL CHECK (gender IN ('M', 'F')),
    ssn          VARCHAR(15)  UNIQUE NOT NULL,
    phone        VARCHAR(20),
    email        VARCHAR(255),
    address_line1   VARCHAR(255),
    address_line2   VARCHAR(255),
    city         VARCHAR(100),
    postal_code  VARCHAR(10),
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_patients_name ON patients (last_name, first_name);
CREATE INDEX idx_patients_ssn ON patients (ssn); 
  
CREATE TABLE consultations ( 
    id                  BIGSERIAL    PRIMARY KEY, 
    patient_id       BIGINT       NOT NULL REFERENCES patients(id), 
    doctor_name         VARCHAR(200) NOT NULL, 
    consultation_date   TIMESTAMP    NOT NULL, 
    symptoms         TEXT, 
    diagnosis        TEXT, 
    notes            TEXT, 
    consultation_type   VARCHAR(50)  NOT NULL, 
    fee_amount          DECIMAL(10,2)   NOT NULL, 
    fee_currency        VARCHAR(3)   NOT NULL DEFAULT 'EUR', 
    is_paid          BOOLEAN      NOT NULL DEFAULT FALSE, 
    created_at          TIMESTAMP    NOT NULL DEFAULT 
CURRENT_TIMESTAMP 
); 
  
CREATE INDEX idx_consultations_patient ON consultations (patient_id); 
CREATE INDEX idx_consultations_date ON consultations (consultation_date); 
CREATE INDEX idx_consultations_doctor ON consultations (doctor_name); 
  
CREATE TABLE prescriptions ( 
    id                  BIGSERIAL    PRIMARY KEY, 
    consultation_id  BIGINT       NOT NULL REFERENCES consultations(id), 
    medication_name     VARCHAR(255) NOT NULL, 
    dosage              VARCHAR(100) NOT NULL, 
    frequency           VARCHAR(100) NOT NULL, 
    duration_days    INTEGER      NOT NULL, 
    notes            TEXT, 
    created_at          TIMESTAMP    NOT NULL DEFAULT 
CURRENT_TIMESTAMP 
); 
  
CREATE INDEX idx_prescriptions_consultation ON prescriptions (consultation_id); 
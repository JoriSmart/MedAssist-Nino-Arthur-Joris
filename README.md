# 🏥 MedAssist - Migration de Base de Données V1 → V2

**Équipe :** Nino, Arthur, Joris  
**Date de début :** 28/04/2026  
**Technologies :** PostgreSQL 16 • Flyway 10 • Docker • SQL  
**Status :** ✅ Scripts implémentés & documentés

---

## 📊 État du Projet

### 🎯 Objectif
Migrer la plateforme MedAssist (système SaaS de gestion de dossiers médicaux) de V1 vers V2 en implémentant 5 évolutions structurelles tout en respectant les contraintes HDS/RGPD (99,9% availability, zéro data loss).

### 📋 Évolutions Cibles

| # | Évolution | Status | Stratégie | Dépendances |
|---|-----------|--------|-----------|------------|
| A | Restructuration adresses (1-N) | ✅ Implémentée | Expand-Contract | Aucune |
| B | Normalisation doctor_name | ✅ Implémentée | Expand-Contract + Dédup | Aucune |
| E | Partitionnement consultations | ✅ Implémentée | Shadow Table + Swap | Aucune |
| C | Update gender field | ✅ Implémentée | Expand-Contract | Aucune |
| D | Chiffrement SSN | ✅ Implémentée | Expand-Contract | Aucune |

**TP Focus :** A, B, E (3 plus critiques) ✅ COMPLÈTES
**Bonus :** C, D ✅ Implémentées

---

## 🚀 Démarrage Rapide

### 1️⃣ Lancer l'environnement
```bash
cd /path/to/MedAssist-Nino-Arthur-Joris
docker-compose up -d postgres
docker-compose run --rm flyway migrate
```

### 2️⃣ Vérifier l'état des migrations
```bash
docker-compose run --rm flyway info
```

### 3️⃣ Se connecter à PostgreSQL
```bash
docker exec -it medassist_pg psql -U medassist_user -d medassist
```

### 4️⃣ Exécuter les tests
```bash
docker exec -it medassist_pg psql -U medassist_user -d medassist -f /tests/test_evolution_A.sql
docker exec -it medassist_pg psql -U medassist_user -d medassist -f /tests/test_evolution_B.sql
docker exec -it medassist_pg psql -U medassist_user -d medassist -f /tests/test_evolution_E.sql
docker exec -it medassist_pg psql -U medassist_user -d medassist -f /tests/test_evolution_C.sql
docker exec -it medassist_pg psql -U medassist_user -d medassist -f /tests/test_evolution_D.sql
```

---

## 📂 Structure des Scripts Flyway

```
flyway/sql/
├── V1__init_schema.sql              # Schema initial ✅
├── V2__seed_data.sql                # Test data ✅
│
├── V2__evolution_A_expand.sql       # Phase 1 : CREATE addresses table
├── V3__evolution_A_backfill.sql     # Phase 2 : Migrate addresses data
├── V4__evolution_A_contract.sql     # Phase 3 : DROP address_* columns
│
├── V5__evolution_B_expand.sql       # Phase 1 : CREATE doctors table
├── V6__evolution_B_backfill.sql     # Phase 2 : Deduplicate & migrate doctors
├── V7__evolution_B_contract.sql     # Phase 3 : DROP doctor_name, add FK
│
├── V9__evolution_E_create_partitioned.sql  # Phase 1 : CREATE partitioned consultations_v2
├── V10__evolution_E_backfill_batched.sql   # Phase 2 : COPY data by batch (5M rows/batch)
├── V11__evolution_E_swap.sql              # Phase 3 : SWAP tables (production cutover)
│
├── V12__evolution_C_expand.sql       # Phase 1 : CREATE gender_ref + gender_code
├── V13__evolution_C_backfill.sql     # Phase 2 : Backfill gender_code
├── V14__evolution_C_contract.sql     # Phase 3 : Replace gender
│
├── V15__evolution_D_expand.sql       # Phase 1 : ADD ssn_encrypted + ssn_hash
├── V16__evolution_D_backfill.sql     # Phase 2 : Encrypt existing SSN
├── V17__evolution_D_contract.sql     # Phase 3 : DROP ssn cleartext
│
└── rollback/
    ├── R_V2__rollback_A.sql         # Rollback Évolution A
    └── (autres rollbacks...)

tests/
├── test_evolution_A.sql    # Tests de validation A
├── test_evolution_B.sql    # Tests de validation B
├── test_evolution_E.sql    # Tests de validation E
├── test_evolution_C.sql    # Tests de validation C
└── test_evolution_D.sql    # Tests de validation D
```

---

## 📝 Détails des Évolutions

### ✅ Évolution A : Restructuration des Adresses

**Problème V1 :** Adresses en colonnes séparées (address_line1, city, postal_code) → Pas de multi-adresses, pas d'historisation, pas de support international

**Solution V2 :** Table `addresses` (1-N avec patients), types (HOME, WORK, BILLING), support pays

**Stratégie :** Expand-Contract  
- V2 : CREATE TABLE addresses + TRIGGER sync
- V3 : INSERT INTO addresses SELECT (backfill)
- V4 : DROP address_* columns

**Files :**
- ✅ V2__evolution_A_expand.sql
- ✅ V3__evolution_A_backfill.sql
- ✅ V4__evolution_A_contract.sql
- ✅ R_V2__rollback_A.sql
- ✅ test_evolution_A.sql

---

### ✅ Évolution B : Normalisation doctor_name

**Problème V1 :** `doctor_name` VARCHAR libre → 6+ variations pour le même médecin

**Solution V2 :** Table `doctors` (RPPS + first_name + last_name), remplacer doctor_name par doctor_id FK

**Stratégie :** Expand-Contract + Déduplication  
- V5 : CREATE TABLE doctors + colonne doctor_id
- V6 : Extraire DISTINCT, dédupliquer, INSERT INTO doctors, UPDATE consultations.doctor_id
- V7 : DROP doctor_name

**Files :**
- ✅ V5__evolution_B_expand.sql
- ✅ V6__evolution_B_backfill.sql
- ✅ V7__evolution_B_contract.sql
- ✅ test_evolution_B.sql

---

### ✅ Évolution E : Partitionnement consultations

**Problème V1 :** `consultations` : 18M lignes, +12k/jour → Scans full table lent

**Solution V2 :** Partitionner par RANGE (consultation_date) : 2021, 2022, 2023, 2024, 2025, future

**Stratégie :** Shadow Table + Rename/Swap + Backfill Batching  
- V9 : CREATE TABLE consultations_v2 (PARTITIONED)
- V10 : COPY data par batch (5M lignes)
- V11 : ALTER TABLE swap (rename old→shadow, v2→consultations)

**Files :**
- ✅ V9__evolution_E_create_partitioned.sql
- ✅ V10__evolution_E_backfill_batched.sql
- ✅ V11__evolution_E_swap.sql
- ✅ test_evolution_E.sql

---

### ✅ Évolution C : Refonte du champ gender

**Problème V1 :** `gender` en CHAR(1) limité à M/F

**Solution V2 :** Table `gender_ref` + `gender` étendu (M/F/NB/U)

**Stratégie :** Expand-Contract  
- V12 : CREATE gender_ref + colonne gender_code + trigger
- V13 : Backfill gender_code
- V14 : Replace gender

**Files :**
- ✅ V12__evolution_C_expand.sql
- ✅ V13__evolution_C_backfill.sql
- ✅ V14__evolution_C_contract.sql
- ✅ test_evolution_C.sql

---

### ✅ Évolution D : Chiffrement SSN

**Problème V1 :** `ssn` en clair

**Solution V2 :** `ssn_encrypted` + `ssn_hash` (pgcrypto)

**Stratégie :** Expand-Contract  
- V15 : ADD ssn_encrypted + ssn_hash + trigger
- V16 : Backfill encryption
- V17 : DROP ssn cleartext

**Files :**
- ✅ V15__evolution_D_expand.sql
- ✅ V16__evolution_D_backfill.sql
- ✅ V17__evolution_D_contract.sql
- ✅ test_evolution_D.sql

---

## ✅ Processus de Validation

Chaque évolution inclut tests :

### 1️⃣ Intégrité des Données
```sql
-- Aucune perte, aucune corruption
SELECT COUNT(*) FROM addresses WHERE patient_id IS NULL;
```

### 2️⃣ Compatibilité Ascendante (V1)
```sql
-- Old queries still work
SELECT * FROM patients p JOIN addresses a ON p.id = a.patient_id;
```

### 3️⃣ Compatibilité Descendante (V2)
```sql
-- New schema queries work
SELECT * FROM consultations c JOIN doctors d ON c.doctor_id = d.id;
```

### 4️⃣ Performance
```sql
EXPLAIN ANALYZE SELECT COUNT(*) FROM consultations 
WHERE consultation_date >= '2024-01-01';
-- Partition pruning: scan only 2024 partition
```

### 5️⃣ Rollback
```bash
docker-compose run --rm flyway -target=1 migrate  # Retour à V1.1
```

---

## 🔄 Plan de Rollback

Chaque évolution est **entièrement réversible** :

```bash
# Rollback complet
docker-compose run --rm flyway undo

# Rollback spécifique
docker-compose run --rm flyway -target=4 migrate  # Retour avant B
```

Scripts fournis :
- R_V3__rollback_evolution_A_expand.sql
- R_V6__rollback_evolution_B_expand.sql
- R_V7__rollback_evolution_B_backfill.sql
- R_V8__rollback_evolution_B_contract.sql
- R_V9__rollback_evolution_E_create_partitioned.sql
- R_V10__rollback_evolution_E_backfill_batched.sql
- R_V11__rollback_evolution_E_swap.sql
- R_V12__rollback_evolution_C_expand.sql
- R_V13__rollback_evolution_C_backfill.sql
- R_V14__rollback_evolution_C_contract.sql
- R_V15__rollback_evolution_D_expand.sql
- R_V16__rollback_evolution_D_backfill.sql
- R_V17__rollback_evolution_D_contract.sql

---

## 📈 Timeline & Fenêtres de Maintenance

| Étape | Durée | Fenêtre | Status |
|-------|-------|---------|--------|
| Évolution A | 2h | 1 dimanche | ✅ Scripts ready |
| Évolution B | 3h | 1-2 dimanches | ✅ Scripts ready |
| Évolution E | 4-5h | 2 dimanches | ✅ Scripts ready |
| Évolution C | 1h | - | ✅ Scripts ready |
| Évolution D | 1-2h | - | ✅ Scripts ready |
| Tests | 2h | - | ✅ Scripts ready |
| Docs | 1h | - | ✅ En cours |

**Total :** ~3-4 fenêtres (dimanches 2h-6h)

---

## 💾 Architecture Technique

### Infrastructure
- **DB :** PostgreSQL 16 (port 5434)
- **Migration :** Flyway 10
- **Orchestration :** Docker Compose
- **Crypto :** pgcrypto (natif PG16)

### Constraints Non-Négociables
✅ **C1** : Zéro perte de données (HDS/RGPD)  
✅ **C2** : SLA 99,9% (max downtime = fenêtre 4h/dimanche)  
✅ **C3** : Rollback possible à chaque étape  
✅ **C4** : Compatibilité V1/V2 pendant rolling deploy  
✅ **C5** : Intégrité référentielle garantie  
✅ **C6** : Performance (< 10% dégradation)  

---

## 📊 Données Clés

| Métrique | Valeur |
|----------|--------|
| Patients | ~2,4M |
| Consultations | ~18M |
| Consultations/jour | ~12k |
| Docteurs uniques | ~120 |
| SLA | 99,9% |
| Fenêtre maintenance | Dimanche 2h-6h (4h) |

---

## 🧪 Commandes Utiles

```bash
# Démarrer
docker-compose up -d postgres
docker-compose run --rm flyway migrate

# Vérifier migrations
docker-compose run --rm flyway info

# Se connecter
docker exec -it medassist_pg psql -U medassist_user -d medassist

# Exécuter target spécifique
docker-compose run --rm flyway -target=5 migrate

# Tests
docker exec -it medassist_pg psql -U medassist_user -d medassist -f tests/test_evolution_A.sql

# Undo
docker-compose run --rm flyway undo
```

---

## 📞 Notes d'Équipe

### ✅ Stratégies Sélectionnées
- **A & B** : Expand-Contract (zéro downtime, compatible rolling deploy)
- **E** : Shadow Table + Swap (permet restructure complète, ~30 min downtime ok)

### ⚠️ Risques Mitigés
1. **Verrouillage** → Batching 5M lignes/batch (E)
2. **Downtime** → Fenêtre dimanche 4h disponible
3. **Incohérences** → Déduplication smart + validation (B)

---

## 📦 Livrables

- ✅ README.md (ce fichier)
- 📝 Scripts Flyway V1→V17
- 🔙 Scripts de rollback
- 🧪 Scripts de tests (test_evolution_*.sql)
- 🐳 docker-compose.yml
- 📊 Documentation d'architecture

---

## 🚦 Prochaines Actions

1. ✅ Lancer `docker-compose up -d postgres`
2. ✅ Exécuter `docker-compose run --rm flyway migrate`
3. ✅ Vérifier `flyway info` (devrait montrer V1 → V17)
4. ✅ Exécuter les tests
5. ✅ Documenter résultats

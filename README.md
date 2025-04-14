# 📊 Analyse des Offres d'Emploi LinkedIn avec Snowflake

**Auteurs** : Paul GIRAUD / Martin MORIN

---

## 🚀 Objectif

Ce projet a pour but d'importer, structurer, nettoyer et analyser des données d’offres d’emploi extraites de LinkedIn via **Snowflake**.  

---

## 1️⃣ Création de la base de données

```sql
CREATE DATABASE linkedin;
USE DATABASE linkedin; -- On spécifie la base de données courante de la session.
```

🎯 *Objectif* : définir une base dédiée à notre projet.

---

## 3️⃣ Création du stage & des formats de fichiers

### 📦 Création du stage (accès au bucket S3)

```sql
CREATE STAGE lab_bucket URL = 's3://snowflake-lab-bucket/';    -- On spécifie le chemin des fichiers à importer
```

### 📂 Vérification du contenu du bucket

```sql
LIST @lab_bucket;
```

🎯 *But* : S'assurer que les fichiers sont accessibles depuis Snowflake.

---

### 🧾 Création des formats de fichier

```sql
CREATE OR REPLACE FILE FORMAT csv
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('\\N', 'NULL')
  EMPTY_FIELD_AS_NULL = TRUE;

CREATE OR REPLACE FILE FORMAT csv_2
  TYPE = 'CSV'
  FIELD_DELIMITER = ';'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('\\N', 'NULL')
  EMPTY_FIELD_AS_NULL = TRUE;

CREATE OR REPLACE FILE FORMAT json 
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE;
```

Les fichiers à charger n'ont pas tous la même structure (délimiteur `,` ou `;`, JSON array, etc.).


---
## 2️⃣ Création du schéma relationnel

### 📘 Tables créées

```sql
CREATE TABLE Jobs_posting (...);
CREATE TABLE Salaries (...);
CREATE TABLE Benefits (...);
CREATE TABLE Companies (...);
CREATE TABLE Skills (...);
CREATE TABLE Employee_counts (...);
CREATE TABLE Job_Skills (...);
CREATE TABLE Industries (...);
CREATE TABLE Job_Industries (...);
CREATE TABLE Company_specialities (...);
CREATE TABLE Company_industries (...);
```

👉 *Commentaires* :
- Clés primaires / étrangères créées pour assurer la cohérence.
- Structure pensée pour représenter les relations **N:N** (ex : `Job_Skills`).

---

## 4️⃣ Chargement des données depuis S3

### 📥 Exemple de commande utilisée

```sql
COPY INTO Jobs_posting
FROM @lab_bucket/jobs_postings.json
FILE_FORMAT = (FORMAT_NAME = json)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;
```

### ⚠️ Problèmes rencontrés

| Problème | Solution |
|---------|----------|
| ❌ Erreur JSON ("one and only one column") | ✅ `STRIP_OUTER_ARRAY = TRUE` |
| ❌ Mauvais mapping de colonnes | ✅ `MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE` |
| ❌ Données hybrides dans `no_of_employ` | ✅ `SPLIT_PART` |
| ❌ Données erronées dans `full_time_remote` | ✅ Nettoyage via `CASE` |
| ❌ Champs vides à interpréter comme NULL | ✅ `EMPTY_FIELD_AS_NULL = TRUE` |

---

## 5️⃣ Nettoyage & Transformation

### 🧹 Extraction des valeurs clés

#### 🔍 Taille d’entreprise et industrie
```sql
SELECT
  TRIM(SPLIT_PART(no_of_employ, '·', 2)) AS industry,
  TRIM(SPLIT_PART(no_of_employ, ' employees', 1)) AS employee_range
FROM Jobs_posting
WHERE no_of_employ IS NOT NULL;
```

🎯 *But* : Séparer deux informations mal structurées dans une seule colonne.

---

#### 🔍 Normalisation des types de contrat
```sql
CASE 
  WHEN full_time_remote LIKE 'Full-time%' THEN 'Full-time'
  WHEN full_time_remote LIKE 'Internship%' THEN 'Internship'
  WHEN full_time_remote LIKE 'Contract%' THEN 'Contract'
  ELSE 'Other'
```

🎯 *But* : Nettoyer les combinaisons incohérentes type `Contract · Remote`.

---

## 6️⃣ Analyses SQL effectuées

### ✅ 1. Top 10 des jobs par industrie

```sql
SELECT 
  i.industry_name,
  jp.job,
  COUNT(*) AS nb_postings
FROM Jobs_posting jp
JOIN Job_Industries ji ON jp.job_ID = ji.job_id
JOIN Industries i ON ji.industry_id = i.industry_id
GROUP BY i.industry_name, jp.job
ORDER BY nb_postings DESC
LIMIT 10;
```

---

### ✅ 2. Répartition par taille d’entreprise

```sql
SELECT 
  TRIM(SPLIT_PART(no_of_employ, ' employees', 1)) AS employee_range,
  COUNT(*) AS nb_postings
FROM Jobs_posting
WHERE no_of_employ IS NOT NULL
GROUP BY employee_range
ORDER BY nb_postings DESC;
```

---

### ✅ 3. Répartition Remote / On-site

```sql
SELECT 
  CASE 
    WHEN full_time_remote = 'TRUE' THEN 'Remote'
    WHEN full_time_remote = 'FALSE' THEN 'On-site'
    ELSE 'Unspecified'
  END AS presence_type,
  COUNT(*) AS nb_postings
FROM Jobs_posting
GROUP BY full_time_remote;
```

---

### ✅ 4. Répartition par type d’emploi

```sql
SELECT 
  CASE 
    WHEN full_time_remote LIKE 'Full-time%' THEN 'Full-time'
    WHEN full_time_remote LIKE 'Part-time%' THEN 'Part-time'
    WHEN full_time_remote LIKE 'Internship%' THEN 'Internship'
    WHEN full_time_remote LIKE 'Contract%' THEN 'Contract'
    ELSE 'Other'
  END AS employment_type,
  COUNT(*) AS nb_postings
FROM Jobs_posting
WHERE full_time_remote IS NOT NULL
AND full_time_remote NOT IN ('1-10 employees', '11-50 employees')
GROUP BY employment_type
ORDER BY nb_postings DESC;
```

---

## 7️⃣ Visualisations avec Streamlit

Voici les visualisations réalisées à partir des analyses SQL, intégrées dans une app interactive.

---

### 📌 1. Top 10 des jobs par industrie (filtrable)

```python
selected_industry = st.selectbox("Sélectionnez une industrie", industries)

query = f"""
SELECT industry, job, job_count
FROM (
  SELECT ci.industry, jp.job, COUNT(*) AS job_count,
         ROW_NUMBER() OVER (PARTITION BY ci.industry ORDER BY COUNT(*) DESC) AS rn
  FROM jobs_posting jp
  LEFT JOIN company_industries ci ON ci.company_id = jp.company_id
  GROUP BY ci.industry, jp.job
) sub
WHERE rn <= 10 AND industry = '{selected_industry}'
ORDER BY job_count DESC;
"""

df = session.sql(query).to_pandas()
st.bar_chart(df, x="JOB", y="JOB_COUNT")
```

<img width="787" alt="image" src="https://github.com/user-attachments/assets/38b4956a-2600-47f2-ab9a-111678f34319" />
---

### 📌 2. Répartition par taille d’entreprise

```python
query = """
SELECT
  SUBSTRING(no_of_employ, 1, CHARINDEX(' employees', no_of_employ) - 1) AS employee_range,
  COUNT(*) AS nb_postings
FROM Jobs_posting
WHERE no_of_employ IS NOT NULL
GROUP BY 1
ORDER BY nb_postings DESC
"""

df = session.sql(query).to_pandas()
st.bar_chart(df, x="EMPLOYEE_RANGE", y="NB_POSTINGS")
```

---

<img width="776" alt="image" src="https://github.com/user-attachments/assets/4863a74e-b16b-4791-b714-243e2deafce0" />

### 📌 3. Répartition Remote / On-site

```python
query = """
SELECT work_type, COUNT(*) as count
FROM jobs_posting
WHERE work_type IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC
"""

df = session.sql(query).to_pandas()
st.plotly_chart(px.pie(df, values="COUNT", names="WORK_TYPE", title="Présence"))
```

---

<img width="751" alt="image" src="https://github.com/user-attachments/assets/8087d93a-085b-42f6-85b8-bddf47bfb50a" />

### 📌 4. Répartition par type d’emploi

```python
query = """
SELECT
  CASE
    WHEN full_time_remote LIKE 'Full-time%' THEN 'Full-time'
    WHEN full_time_remote LIKE 'Contract%' THEN 'Contract'
    WHEN full_time_remote LIKE 'Part-time%' THEN 'Part-time'
    WHEN full_time_remote LIKE 'Internship%' THEN 'Internship'
    ELSE full_time_remote
  END AS type_emploi,
  COUNT(*) AS count
FROM jobs_posting
WHERE full_time_remote NOT IN ('1-10 employees', '11-50 employees')
  AND full_time_remote IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC
"""

df = session.sql(query).to_pandas()
st.plotly_chart(px.pie(df, values="COUNT", names="TYPE_EMPLOI", title="Type d’emploi"))
```

---

<img width="765" alt="image" src="https://github.com/user-attachments/assets/1c3d7069-20bd-4dcd-8aaa-c5f1a9bcd3f3" />

## 🧠 Conclusion

Ce projet nous a permis de :

- Mettre en œuvre une pipeline d’analyse de données dans Snowflake.
- Manipuler et nettoyer des données hétérogènes et partiellement structurées.
- Résoudre plusieurs problèmes courants liés aux formats (CSV, JSON, délimiteurs).
- Créer un dashboard interactif clair et ergonomique.

---

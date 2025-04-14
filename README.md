# 📊 Analyse des Offres d'Emploi LinkedIn avec Snowflake

**Auteurs** : Paul GIRAUD / Martin MORIN

Les fichiers de code SQL / Streamlit sont disponibles sur ce même repo GitHub : "linkedin
---

## 🚀 Objectif

Ce projet a pour but d'importer, structurer, nettoyer et analyser des données d’offres d’emploi extraites de LinkedIn via **Snowflake**.  

---

## 1️⃣ Création de la base de données

On ouvre un SQL Worksheet.
On commence par créer une base de données "linkedin".
```sql
CREATE DATABASE linkedin;  --  Création de la base de données "linkedin".
USE DATABASE linkedin; -- On spécifie la base de données courante de la session.
```

---

## 2️⃣ Création du stage & des formats de fichiers

### 📦 Création du stage (accès au bucket S3)

On crée un stage pour spécifier l'emplacement des fichiers de données
```sql
CREATE STAGE lab_bucket URL = 's3://snowflake-lab-bucket/';    -- On spécifie où se situent les fichiers à importer
```

### 📂 Vérification du contenu du bucket

On vérifie que tous les fichiers sont bien présents là où on l'a spécifié
```sql
LIST @lab_bucket;
```

On obtient la liste des fichiers présents dans le bucket S3.
<img width="942" alt="image" src="https://github.com/user-attachments/assets/fb891f1e-a94a-4159-aee3-b227915c8b84" />


### 🧾 Création des formats de fichiers

On crée différents formats de fichiers pour importer les fichiers de données qui présentent des types et des délimiteurs différents. 
Ils n'ont pas tous la même structure.
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

---
## 3️⃣ Création des tables

On crée toutes les tables qui vont accueillir nos données par la suite.
On prend soin de bien définir les bons types de données pour chaque colonne.
```sql
-- Création des tables
CREATE OR REPLACE TABLE Jobs_posting (
    job_ID STRING PRIMARY KEY,
    job STRING,
    location STRING,
    company_id STRING,
    company_name STRING,
    work_type STRING,
    full_time_remote STRING,
    no_of_employ STRING,
    no_of_application STRING,
    posted_day_ago STRING,
    alumni STRING,
    Hiring_person STRING,
    linkedin_followers STRING,
    hiring_person_link STRING,
    job_details STRING
);

CREATE OR REPLACE TABLE Salaries (
    salary_id STRING PRIMARY KEY,
    job_id STRING REFERENCES Jobs_posting(job_ID),
    max_salary NUMBER,
    med_salary NUMBER,
    min_salary NUMBER,
    pay_period STRING,
    currency STRING,
    compensation_type STRING
);

CREATE OR REPLACE TABLE Benefits (
    job_id STRING REFERENCES Jobs_posting(job_ID),
    type STRING,
    inferred STRING
);

CREATE OR REPLACE TABLE Companies (
    company_id STRING PRIMARY KEY,
    name STRING,
    description STRING,
    company_size NUMBER(1),
    country STRING,
    state STRING,
    city STRING,
    zip_code STRING,
    address STRING,
    url STRING
);

CREATE OR REPLACE TABLE Skills (
    skill_abr STRING PRIMARY KEY,
    skill_name STRING
);

CREATE OR REPLACE TABLE Employee_counts (
    company_id STRING REFERENCES Companies(company_id),
    employee_count INTEGER,
    follower_count INTEGER,
    time_recorded FLOAT
);

CREATE OR REPLACE TABLE Job_Skills (
    job_id STRING REFERENCES Jobs_posting(job_ID),
    skill_abr STRING REFERENCES Skills(skill_abr),
    PRIMARY KEY (job_id, skill_abr)
);

CREATE OR REPLACE TABLE Industries (
    industry_id STRING PRIMARY KEY,
    industry_name STRING
);

CREATE OR REPLACE TABLE Job_Industries (
    job_id STRING REFERENCES Jobs_posting(job_ID),
    industry_id STRING REFERENCES Industries(industry_id),
    PRIMARY KEY (job_id, industry_id)
);

CREATE OR REPLACE TABLE Company_specialities (
    company_id STRING REFERENCES Companies(company_id),
    speciality STRING,
    PRIMARY KEY (company_id, speciality)
);

CREATE OR REPLACE TABLE Company_industries (
    company_id STRING REFERENCES Companies(company_id),
    industry STRING REFERENCES Industries(industry_id),
    PRIMARY KEY (company_id, industry)
);

```

---

## 4️⃣ Chargement des données depuis S3

On insère nos données dans les tables que l'on vient de créer.
```sql
COPY INTO Benefits
FROM @lab_bucket/benefits.csv
FILE_FORMAT = csv;

COPY INTO Companies
FROM @lab_bucket/companies.json
FILE_FORMAT = json
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO Company_industries
FROM @lab_bucket/company_industries.json
FILE_FORMAT = json
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO Company_specialities
FROM @lab_bucket/company_specialities.json
FILE_FORMAT = json
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO Employee_counts
FROM @lab_bucket/employee_counts.csv
FILE_FORMAT = csv;

COPY INTO Industries
FROM @lab_bucket/industries.json
FILE_FORMAT = json
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO Job_Industries
FROM @lab_bucket/job_industries.json
FILE_FORMAT = json
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO Jobs_posting
FROM @lab_bucket/job_postings.csv
FILE_FORMAT = csv_2;

COPY INTO Job_Skills
FROM @lab_bucket/job_skills.csv
FILE_FORMAT = csv;

COPY INTO Salaries
FROM @lab_bucket/salaries.csv
FILE_FORMAT = csv;

COPY INTO Skills
FROM @lab_bucket/skills.csv
FILE_FORMAT = csv;

```

---

## 5️⃣ Analyses SQL effectuées

### ✅ 1. Top 10 des jobs par industrie

```sql
SELECT
    industry,
    job,
    job_count

FROM (

    SELECT
        ci.industry,
        jp.job,
        COUNT(*) AS job_count,
        ROW_NUMBER() OVER (PARTITION BY ci.industry ORDER BY COUNT(*) DESC) AS rn
    FROM jobs_posting jp
    LEFT JOIN company_industries ci ON ci.company_id = jp.company_id
    GROUP BY ci.industry, jp.job

) sub

WHERE rn <= 10

ORDER BY job_count DESC
```
<img width="935" alt="image" src="https://github.com/user-attachments/assets/bb8fb0cd-7838-4a21-ac3a-7273caec7d63" />


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
<img width="943" alt="image" src="https://github.com/user-attachments/assets/c04beb02-4c51-4071-a427-a0f6d96b7557" />


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
<img width="939" alt="image" src="https://github.com/user-attachments/assets/d3b0935c-60c4-404a-9568-d71bf3927d8c" />


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
<img width="939" alt="image" src="https://github.com/user-attachments/assets/88fa5ba8-43b2-49a5-aeff-eed43a809d0d" />


---

## 6️⃣ Visualisations avec Streamlit

Voici les visualisations réalisées à partir des analyses SQL, intégrées dans une app Streamlit.

---

⚠️ Il faut installer les packages "matplotlib" et "pandas" avant d'exécuter le code.
<img width="437" alt="image" src="https://github.com/user-attachments/assets/6837d3ce-67b8-40bc-b90c-728fa50012d8" />

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

### 📌 2. Répartition des offres d'emploi par taille d’entreprise

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

### 📌 3. Répartition des offres d'emploi par type de présence

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

### 📌 4. Répartition des offres d'emploi par type d’emploi

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

---

### ⚠️ Problèmes rencontrés et solutions apportées

| **Problème** | **Détail** | **Solution** |
|--------------|------------|--------------|
| ❌ **Erreur JSON : `one and only one column`** | Lors du chargement de fichiers JSON contenant des tableaux d'objets, Snowflake renvoie cette erreur si le format n’est pas correctement défini. Cela se produit notamment lorsque le fichier JSON commence par `[` et contient plusieurs objets. | ✅ **Ajout de `STRIP_OUTER_ARRAY = TRUE`** dans le `FILE FORMAT` JSON pour indiquer que les données sont dans un tableau et doivent être traitées ligne par ligne. |
| ❌ **Mauvais mapping des colonnes lors du `COPY INTO`** | Si les noms des colonnes dans le fichier source ne correspondent pas exactement (casse, ordre, etc.) aux noms des colonnes dans la table cible, le chargement échoue ou les colonnes sont mal alignées. | ✅ Ajout de l’option **`MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE`** pour ignorer la casse et s’assurer que les noms sont correctement associés. |
| ❌ **Données hybrides dans la colonne `no_of_employ`** | Cette colonne contient des chaînes de type `"11-50 employees"`, ce qui empêche une analyse directe des tailles. | ✅ Utilisation de **`SPLIT_PART(no_of_employ, ' ', 1)`** ou **`SUBSTRING` + `CHARINDEX`** pour extraire uniquement la plage `"11-50"`. |
| ❌ **Valeurs erronées dans `full_time_remote`** | Cette colonne contient parfois des données qui ne sont pas des types d’emploi (ex : des tailles d’entreprises comme `"11-50 employees"`). | ✅ Nettoyage avec une clause **`CASE WHEN`** pour filtrer uniquement les valeurs `"Full-time"`, `"Contract"`, `"Part-time"` et `"Internship"`, et exclure les autres. |
| ❌ **Champs vides interprétés comme chaîne vide au lieu de NULL** | Certaines valeurs manquantes sont des chaînes vides (`""`) ou `"NULL"` écrit en dur, ce qui fausse les analyses. | ✅ Utilisation de **`EMPTY_FIELD_AS_NULL = TRUE`** et **`NULL_IF = ('\\N', 'NULL')`** dans les `FILE FORMAT` pour forcer ces champs à être reconnus comme NULL. |

---

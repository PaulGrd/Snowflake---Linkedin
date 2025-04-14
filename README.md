# Snowflake - Linkedin
Rendu de projet - Paul GIRAUD / Martin MORIN

Voici ton `README.md` tout propre, prêt à copier-coller dans ton repo GitHub 💾 :

---

```markdown
# 📊 Analyse des Offres d'Emploi LinkedIn avec Snowflake

## 🚀 Objectif

Ce projet a pour but d'importer, structurer et analyser des données d’offres d’emploi extraites de LinkedIn à l’aide de **Snowflake**. L’objectif est d’obtenir des insights comme la répartition des offres par type d'emploi, industrie ou encore taille d’entreprise.

---

## 🧱 Architecture

### 🗂️ Base de données
- `linkedin`

### ☁️ Stockage externe
- Données stockées sur un bucket Amazon S3 :
  ```
  s3://snowflake-lab-bucket/
  ```

### 📦 Formats de fichiers
- CSV (`csv`, `csv_2`)
- JSON (`json` avec `STRIP_OUTER_ARRAY = TRUE` et `MATCH_BY_COLUMN_NAME`)

---

## 🗃️ Schéma de la base

### 🔸 Tables créées
- `Jobs_posting`
- `Salaries`
- `Benefits`
- `Companies`
- `Skills`
- `Employee_counts`
- `Job_Skills`
- `Industries`
- `Job_Industries`
- `Company_specialities`
- `Company_industries`

👉 Relations établies via clés primaires et étrangères pour garantir l’intégrité des données.

---

## 📥 Import des données

### 🗂️ Données chargées depuis S3
```sql
COPY INTO TableName
FROM @lab_bucket/file_name
FILE_FORMAT = json_or_csv
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;
```

### ⚠️ Problèmes & Solutions

| Problème | Solution |
|---------|----------|
| ❌ Erreur JSON : "can produce one and only one column..." | ✅ Utilisation de `MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE` |
| ❌ `job_id` non liés entre certaines tables | ✅ Vérification manuelle et croisement des données |
| ❌ Données mêlant taille d’entreprise + industrie | ✅ Split SQL via `SPLIT_PART()` |
| ❌ `full_time_remote` contient des valeurs incohérentes | ✅ Nettoyage et regroupement par `CASE` |

---

## 🧹 Nettoyage & Transformation

### 🔎 Exemple de parsing `no_of_employ` :
```sql
SELECT
  TRIM(SPLIT_PART(no_of_employ, '·', 2)) AS industry,
  TRIM(SPLIT_PART(no_of_employ, ' employees', 1)) AS employee_range
FROM Jobs_posting
WHERE no_of_employ IS NOT NULL;
```

### 🔎 Regroupement des types de contrat :
```sql
CASE 
  WHEN full_time_remote LIKE 'Full-time%' THEN 'Full-time'
  WHEN full_time_remote LIKE 'Internship%' THEN 'Internship'
  ...
```

---

## 📈 Analyses SQL

### 1️⃣ Top 10 des jobs les plus publiés par industrie
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

### 2️⃣ Répartition des offres par taille d’entreprise
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

### 3️⃣ Répartition des offres Remote vs On-site
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

### 4️⃣ Répartition des offres par type d’emploi
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

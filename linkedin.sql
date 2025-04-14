-- Création de la base de données "linkedin"
create or replace database linkedin;

-- Création du stage spécifiant l'emplacement du bucket s3
create stage lab_bucket url = 's3://snowflake-lab-bucket/';

-- Vérification des fichiers présents dans le bucket s3
list @lab_bucket;

-- Création des formats de fichier à charger
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

CREATE or REPLACE file format json 
type = 'JSON'
STRIP_OUTER_ARRAY=TRUE;

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

-- Insertion des données dans les tables
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



----- Analyse des données -----

-- 1. Quel est le top 10 des jobs les plus publiés par industrie ?

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

ORDER BY job_count DESC;


-- 2. Quelle est la répartition des offres d’emploi par taille d’entreprise ?
SELECT 
    SUBSTRING(no_of_employ, 1, CHARINDEX(' employees', no_of_employ) - 1) AS employee_range,
    COUNT(*) AS nb_postings
FROM Jobs_posting
WHERE no_of_employ is not null
GROUP BY all
ORDER BY COUNT(*) desc;

-- 3. Quelle est la répartition des offres d’emploi par type de presénce (Remote vs On-site) ?
SELECT 
    work_type,
    COUNT(*) AS nb_postings
FROM Jobs_posting
WHERE work_type is not null
GROUP BY work_type
ORDER BY COUNT(*) desc;

-- 4. Quelle est la répartition des offres d’emploi par type d’emploi (temps plein, stage, temps partiel) ?
SELECT 
    CASE 
        WHEN full_time_remote LIKE 'Full-time%' THEN 'Full-time'
        WHEN full_time_remote LIKE 'Part-time%' THEN 'Part-time'
        WHEN full_time_remote LIKE 'Contract%' THEN 'Contract'
        WHEN full_time_remote LIKE 'Internship%' THEN 'Internship'
        ELSE full_time_remote
    END AS full_time_remote,
    COUNT(*) AS nb_postings
FROM Jobs_posting
WHERE full_time_remote is not null
and full_time_remote NOT IN ('1-10 employees','11-50 employees')
GROUP BY all
ORDER BY COUNT(*) desc;

# ⚠️ Il faut installer les packages "matplotlib" et "pandas" avant d'exécuter le code.
import streamlit as st

from snowflake.snowpark.context import get_active_session

import matplotlib.pyplot as plt

import pandas as pd

# Obtenir la session Snowflake active

session = get_active_session()

# Interface principale

st.title("Analyse des offres d'emploi :bar_chart:")

st.write("""

Ce tableau de bord présente une analyse des offres d'emploi basée sur différents critères.

""")

# Visualisation 1: Top 10 des jobs les plus publiés par industrie

st.header("Top 10 des jobs les plus publiés par industrie")

# Obtenir la liste des industries

industries_query = "SELECT DISTINCT industry FROM company_industries WHERE industry IS NOT NULL ORDER BY industry"

industries_data = session.sql(industries_query).collect()

industries = [row['INDUSTRY'] for row in industries_data]

selected_industry = st.selectbox("Sélectionnez une industrie", industries)

# Exécuter la requête pour l'industrie sélectionnée

top_jobs_query = f"""

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

WHERE rn <= 10 AND industry = '{selected_industry}'

ORDER BY job_count DESC

"""

top_jobs_data = session.sql(top_jobs_query).collect()

# Afficher le graphique

st.subheader(f"Top 10 des jobs dans l'industrie: {selected_industry}")

st.bar_chart(data=top_jobs_data, x="JOB", y="JOB_COUNT")

# Visualisation 2: Répartition des offres d'emploi par taille d'entreprise

st.header("Répartition des offres d'emploi par taille d'entreprise")

size_query = """

SELECT

    SUBSTRING(no_of_employ, 1, CHARINDEX(' employees', no_of_employ) - 1) AS employee_range,

    COUNT(*) AS nb_postings

FROM Jobs_posting

WHERE

    no_of_employ is not null

GROUP BY 1

ORDER BY nb_postings DESC

"""

size_data = session.sql(size_query).collect()

st.bar_chart(data=size_data, x="EMPLOYEE_RANGE", y="NB_POSTINGS")

# Visualisation 3: Répartition des offres d'emploi par type de présence (camembert)

st.header("Répartition des offres d'emploi par type de présence")

presence_query = """

SELECT

    work_type,

    COUNT(*) as count

FROM jobs_posting jp

WHERE

    work_type IS NOT NULL

GROUP BY 1

ORDER BY 2 DESC

"""

presence_data = session.sql(presence_query).collect()

presence_df = pd.DataFrame(presence_data)

# Calculer les pourcentages pour la légende

total_presence = presence_df['COUNT'].sum()

presence_percentages = [(value / total_presence) * 100 for value in presence_df['COUNT']]

presence_labels = [f"{label} ({percentage:.1f}%)" for label, percentage in zip(presence_df['WORK_TYPE'], presence_percentages)]

# Créer un camembert pour la présence avec légende

fig1, ax1 = plt.subplots(figsize=(12, 8))

ax1.pie(presence_df['COUNT'], labels=None, startangle=90)

ax1.axis('equal')  # Pour que le camembert soit circulaire

plt.title('Répartition par type de présence')

plt.legend(presence_labels, loc="center left", bbox_to_anchor=(1, 0.5))

st.pyplot(fig1)

# Visualisation 4: Répartition des offres d'emploi par type d'emploi (camembert)

st.header("Répartition des offres d'emploi par type d'emploi")

job_type_query = """

SELECT

    CASE

        WHEN full_time_remote LIKE 'Full-time%'THEN 'Full-time'

        WHEN full_time_remote LIKE 'Contract%'THEN 'Contract'

        WHEN full_time_remote LIKE 'Part-time%'THEN 'Part-time'

        WHEN full_time_remote LIKE 'Internship%'THEN 'Internship'

        ELSE full_time_remote

        END AS type_emploi,

    COUNT(*) AS count

FROM jobs_posting jp

WHERE

    full_time_remote NOT IN ('1-10 employees', '11-50 employees')

    AND full_time_remote IS NOT NULL

GROUP BY 1

ORDER BY 2 DESC

"""

job_type_data = session.sql(job_type_query).collect()

job_type_df = pd.DataFrame(job_type_data)

# Calculer les pourcentages pour la légende

total_job_type = job_type_df['COUNT'].sum()

job_type_percentages = [(value / total_job_type) * 100 for value in job_type_df['COUNT']]

job_type_labels = [f"{label} ({percentage:.1f}%)" for label, percentage in zip(job_type_df['TYPE_EMPLOI'], job_type_percentages)]

# Créer un camembert pour le type d'emploi avec légende

fig2, ax2 = plt.subplots(figsize=(12, 8))

ax2.pie(job_type_df['COUNT'], labels=None, startangle=90)

ax2.axis('equal')  # Pour que le camembert soit circulaire

plt.title('Répartition par type d\'emploi')

plt.legend(job_type_labels, loc="center left", bbox_to_anchor=(1, 0.5))

st.pyplot(fig2)

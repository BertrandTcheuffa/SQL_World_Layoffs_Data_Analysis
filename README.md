
# Global Layoffs Analysis (2020–2023)

## SQL Data Cleaning & Exploratory Data Analysis Project

This project analyzes **global technology layoffs between 2020 and 2023** using SQL.  
It demonstrates the **complete workflow of a data analyst**, from raw data preparation to analytical insight generation.

The objective of this project was to:

- Clean and prepare a real-world dataset
- Handle common data quality issues
- Perform exploratory data analysis using SQL
- Extract meaningful business insights
- Demonstrate production-quality SQL practices

The analysis was implemented using **MySQL 8** and executed in **MySQL Workbench**.

---

# Table of Contents

1. [Project Overview](#project-overview)  
2. [Dataset Description](#dataset-description)  
3. [Project Architecture](#project-architecture)  
4. [Data Cleaning Process](#data-cleaning-process)  
5. [Exploratory Data Analysis (EDA)](#exploratory-data-analysis)  
6. [Business Insights](#business-insights)  
7. [SQL Skills Demonstrated](#sql-skills-demonstrated)   
8. [Potential Future Improvements](#potential-future-improvements)  
9. [References](#references)

---

# Project Overview

Large-scale layoffs in the technology sector became a major global phenomenon following the COVID-19 pandemic and the economic slowdown of 2022–2023.<br>

This project analyzes layoffs across companies worldwide to answer questions such as:

- Which companies laid off the most employees?
- Which industries were most affected?
- Which countries experienced the largest layoffs?
- How did layoffs evolve over time?
- Which companies experienced the highest relative layoffs?

The project demonstrates how SQL can be used not only for **data extraction**, but also for **data cleaning, transformation, and analytical exploration**.

---

# Dataset Description

The dataset contains documented layoffs from technology companies between **2020 and 2023**.

Each row represents a **layoff event**.

| Column | Description |
|------|-------------|
| company | Company name |
| location | Company headquarters location |
| industry | Industry sector |
| total_laid_off | Number of employees laid off |
| percentage_laid_off | Percentage of workforce laid off |
| date | Date of the layoff |
| stage | Company funding stage |
| country | Country of the company |
| funds_raised_millions | Total funding raised by the company |

---

# Project Architecture

```
layoffs-sql-analysis
│
├── data
│   └── layoffs.csv
│
├── sql
│   ├── data_cleaning_project.sql
│   └── exploratory_analysis_project.sql
│
└── README.md
```

The project consists of two main SQL scripts:

1. **Data Cleaning Script** – transforms raw data into a clean analysis-ready dataset.
2. **Exploratory Data Analysis Script** – performs analytical queries and extracts insights.

---

# Data Cleaning Process

Real-world datasets often contain inconsistencies, duplicates, and missing values. <br>
At the begin of the process, it is best practice to create a staging file to preserve to raw file.


### Data Standardization

Several inconsistencies were corrected:

- Trimmed all text columns like company, location, industry, stage. It helps standardizing the columns for a later identification of duplicates.
  
```sql
SET company  = NULLIF(TRIM(company), ''),
    location = NULLIF(TRIM(location), ''), ...;
```
  
- Standardized country names (for example 'United States' is used in replacement of 'United States.')

```sql
UPDATE layoffs_staging
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';
```

- Normalized industry labels (for example `Crypto` in replacement of 'CryptoCurrency')
- Corrected location spelling  by unifying Düsseldorf spelling to ASCII
       
### Parse and type-cast dates and numeric fields for consistent use in data analysis and BI

Most columns were defines as TEXT data in the raw table.
There were  converted to VARCHAR for accuracy.
Data type of the columns ` percentage_laid_off` and `funds_raised_millions` data were set to DECIMAL
Dates were converted into SQL DATE format:

```sql
STR_TO_DATE(date, '%m/%d/%Y')
```

### Duplicate removal

The strategy was to use the window function ROW_NUMBER() to detect the first occurrence of identical records (row_num = 1). All other occurences (row_num > 1) are removed.
Partitionning over all columns helps identifying unique rows.

Unique rows were identified by the following CTE:

```sql
WITH numbered AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY
        company, location, industry,
        total_laid_off, percentage_laid_off,
        `date`, stage, country, funds_raised_millions
      ORDER BY company
    ) AS row_num
  FROM layoffs_clean
)
SELECT
  company, location, industry,
  total_laid_off, percentage_laid_off,
  `date`, stage, country, funds_raised_millions
FROM numbered
WHERE row_num = 1;
```


### Handling Missing Data

Techniques applied:

- Missing industries are inferred  by matching on company name using SELF JOIN

```sql
       UPDATE layoffs_clean t1
       JOIN layoffs_clean t2
         ON t1.company = t2.company
       SET t1.industry = t2.industry
       WHERE t1.industry IS NULL
         AND t2.industry IS NOT NULL;
  ```

- Records missing both layoff metrics are removed.

```sql
       DELETE FROM layoffs_clean
       WHERE total_laid_off IS NULL
         AND percentage_laid_off IS NULL;
```
Once the data was cleaned, the extraction of meaningful insights follows.

---

# Exploratory Data Analysis

Prior to the EDA, basic data quality, time, amplitude and duplicates checks were performed again in the first place.


SQL queries were used to analyze patterns such as:

- Layoffs by company
- Layoffs by industry
- Layoffs by country
- Layoffs over time
- Layoff severity levels...


### Identifying the social impact by analysing companies, where the entire workforce was cancelled (percentage_laid_off = 1)


```sql
SELECT *
FROM layoffs_clean
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC
LIMIT 50;
```
It appears that most companies shutdown were registered in the contruction, food and retail sector in the United States.


### Identifying the financial impact on investors by analysing well-funded companies that completly failed (percentage_laid_off = 1)

```sql
SELECT *
FROM layoffs_clean
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC
LIMIT 50;
```
'Britishvolt', 'Quibi' and 'Delivero Australia' were  the best well-funded companies (2400 + 1800 + 1700.0 millions) that totally failed. 


### Total layoffs by company

```sql
SELECT company,
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
GROUP BY company
ORDER BY total_laid_off DESC;
```
Big tech companies like Amazon, Google, Meta, Saleforce and Meta laid off the most employees in the consiedered period due to the economic slowdown caused by the COVID-19 pandemic.


### Total layoffs by industry

```sql
SELECT
  industry,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE total_laid_off IS NOT NULL
GROUP BY industry
ORDER BY total_laid_off DESC
LIMIT 50;
```
The consumer and the retail industry were the most affected segment.


### Monthly layoffs trend

```sql
SELECT DATE_FORMAT(date, '%Y-%m') AS month,
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
GROUP BY month
ORDER BY month;
```
January 2023 with 84714 layoffs appears to be the month with the most layoffs.


### Rolling cumulative layoffs

```sql
WITH monthly_layoffs_cte AS (
  SELECT
    DATE_FORMAT(`date`, '%Y-%m') AS `month`,
    SUM(total_laid_off) AS monthly_total_laid_off
  FROM layoffs_clean
  WHERE `date` IS NOT NULL
    AND total_laid_off IS NOT NULL
  GROUP BY `month`
SELECT
  `month`,
  monthly_total_laid_off,
  SUM(monthly_total_laid_off) OVER (ORDER BY `month`) AS rolling_total_laid_off -- Uses window function SUM() OVER() to perform the rolling total
FROM monthly_layoffs_cte
ORDER BY `month` ASC;
```
With rolling cumulative layoffs, the monthly progression of the layoffs can be observed.


### Month-over-month change to spot spikes

By establishing the side-by-side comparision between the actual monthly layoffs and the previous monthly layoffs, spikes can be spotted.<br>
This is achieved by a concatenation of CTEs.<br>
The first CTE is used to get the monthly layoffs. The second CTE uses the window function LAG() to get for each month the previous monthly layoffs.<br>
With both informations combined, the monthly absolute change and the monthly percentage change can be computed.

```sql
WITH monthly_cte AS (
  SELECT
    DATE_FORMAT(`date`, '%Y-%m') AS `month`,
    SUM(total_laid_off) AS monthly_total_laid_off
  FROM layoffs_clean
  WHERE `date` IS NOT NULL
    AND total_laid_off IS NOT NULL
  GROUP BY DATE_FORMAT(`date`, '%Y-%m')
),
mom_cte AS (
  SELECT
    `month`,
    monthly_total_laid_off,
    LAG(monthly_total_laid_off) OVER (ORDER BY `month`) AS prev_month_total
  FROM monthly_cte
)
SELECT
  `month`,
  monthly_total_laid_off,
  prev_month_total,
  (monthly_total_laid_off - prev_month_total) AS mom_abs_change,
  CASE
    WHEN prev_month_total IS NULL OR prev_month_total = 0 THEN NULL
    ELSE (monthly_total_laid_off - prev_month_total) / prev_month_total
  END AS mom_pct_change
FROM mom_cte
ORDER BY `month` ASC;
```


### Top companies per year

**For each year, which are the top five companies with the most layoffs?**<br>
To answer this question, two CTEs were combined.<br>
In the first CTE, for each company, the yearly total of layoffs is computed.<br>
The second CTE calculates for each year and company a ranking measured by the total layoffs.<br>

```sql
SELECT
    company,
    YEAR(`date`) AS `year`,
    SUM(total_laid_off) AS total_laid_off
  FROM layoffs_clean
  WHERE `date` IS NOT NULL
    AND total_laid_off IS NOT NULL
  GROUP BY company, YEAR(`date`)
),
ranked_cte AS (
-- CTE to rank the companies by year and total layoffs based on the previous one. 
  SELECT
    company, `year`, total_laid_off,
    DENSE_RANK() OVER (PARTITION BY `year` ORDER BY total_laid_off DESC) AS ranking
  FROM company_year_cte
  WHERE `year` IS NOT NULL
)
SELECT * -- Get the top 5 companies by total layoffs
FROM ranked_cte
WHERE ranking <= 5
ORDER BY `year` ASC, ranking ASC, company ASC;
```

---

# Business Insights

The analysis reveals:

- Layoffs were concentrated among a small number of companies.
- Certain sectors such as consumer, tech and crypto were heavily affected.
- Layoffs increased significantly during the 2022–2023 economic slowdown.
- Some companies shut down completely while others reduced workforce moderately.

---

# SQL Skills Demonstrated

### Data Cleaning
- Duplicate detection
- Data standardization
- Handling NULL values
- Data type conversion

### Analytical SQL
- Aggregations
- Filtering
- Common Table Expression
- Conditional logic
- Window functions
- Ranking queries
- Time-series analysis

Key SQL features used:

- ROW_NUMBER()
- DENSE_RANK()
- CASE
- DATE_FORMAT
- GROUP BY
- CTE

---


# Potential Future Improvements

Possible extensions:

- Data visualization using Tableau or Power BI
- Predictive modeling using Python
- Time-series forecasting

---

# References

Ultimate Data Analyst Bootcamp | SQL, Excel, Tableau, Power BI, Python, Azure

https://www.youtube.com/watch?v=wQQR60KtnFY&t=32423s

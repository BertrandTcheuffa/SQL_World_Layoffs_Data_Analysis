
# Global Tech Layoffs Analysis (2020–2023)

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
5. [Exploratory Data Analysis](#exploratory-data-analysis)  
6. [Key Analytical Queries](#key-analytical-queries)  
7. [Business Insights](#business-insights)  
8. [SQL Skills Demonstrated](#sql-skills-demonstrated)   
9. [Potential Future Improvements](#potential-future-improvements)  
10. [References](#References)

---

# Project Overview

Large-scale layoffs in the technology sector became a major global phenomenon following the COVID-19 pandemic and the economic slowdown of 2022–2023.

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

Real-world datasets often contain inconsistencies, duplicates, and missing values.
At the begin of the process, it is best practice to create a staging file to preserve to raw table layoffs.csv file.


### Data Standardization

Several inconsistencies were corrected:

- Trimmed all text fields like company, location, industry, stage
  
  ```sql
         SET company  = NULLIF(TRIM(company), ''),
             location = NULLIF(TRIM(location), ''), ...;
  ```
  
- Normalized selected categorical values:
       - Standardized country names (for example 'United States' in replacement of 'United States.')

 ```sql
        UPDATE layoffs_staging
       SET country = TRIM(TRAILING '.' FROM country)
       WHERE country LIKE 'United States%';
  ```

       - Normalized industry labels (for example `Crypto` in replacement of 'CryptoCurrency')
       - Corrected location spelling  by unifying Düsseldorf spelling to ASCII
       
### Parse and type-cast dates and numeric fields for consistent analysis and BI

Most columns were defines as TEXT data in the raw table.
There were  set to VARCHAR for efficiency.
Data type of the columns ` percentage_laid_off` and `funds_raised_millions` data were set to DECIMAL
Dates were converted into SQL DATE format:

```sql
STR_TO_DATE(date, '%m/%d/%Y')
```

### Duplicate Detection

The strategy was to use the window function ROW_NUMBER() to detect the first occurrence of each identical record.
Partitionning over all columns then make sure to clearly identify duplicated rows, that appears with `row_number` greater than 1

Unique rows were identified by:

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

This allowed identification and removal of duplicate layoff events (row_num > 1).

### Handling Missing Data

Techniques applied:

- Missing industries inferred  by matching on company name using SELF JOIN

```sql
       UPDATE layoffs_clean t1
       JOIN layoffs_clean t2
         ON t1.company = t2.company
       SET t1.industry = t2.industry
       WHERE t1.industry IS NULL
         AND t2.industry IS NOT NULL;
  ```

- Records missing both layoff metrics removed

```sql
       DELETE FROM layoffs_clean
       WHERE total_laid_off IS NULL
         AND percentage_laid_off IS NULL;
```
Basic data quality checks (ranges, impossible values) were made at the end on numerical columns to validate their integrity.
---

# Exploratory Data Analysis

Once the dataset was cleaned, SQL queries were used to analyze patterns such as:

- Layoffs by company
- Layoffs by industry
- Layoffs by country
- Layoffs over time
- Layoff severity levels

Severity categories were defined based on the percentage of workforce affected.

| Category | Percentage |
|------|------|
| 100% | Entire workforce |
| 50–99% | Severe layoffs |
| 20–49% | Medium layoffs |
| 1–19% | Minor layoffs |

---

# Key Analytical Queries

## Total layoffs by company

```sql
SELECT company,
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
GROUP BY company
ORDER BY total_laid_off DESC;
```

## Monthly layoffs trend

```sql
SELECT DATE_FORMAT(date, '%Y-%m') AS month,
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
GROUP BY month
ORDER BY month;
```

## Rolling cumulative layoffs

```sql
SUM(monthly_total_laid_off) OVER (ORDER BY month)
```

## Top companies per year

```sql
DENSE_RANK() OVER (PARTITION BY year ORDER BY total_laid_off DESC)
```

---

# Business Insights

The analysis reveals:

- Layoffs were concentrated among a small number of companies.
- Certain sectors such as consumer tech and crypto were heavily affected.
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
- Window functions

---

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

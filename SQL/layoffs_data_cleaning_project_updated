/*
Layoffs dataset (2020–2023) — Data Cleaning Script 
Target: (MySQL 8+)

Before starting:
- The layoffs.csv has been downloaded and imported into a raw table named `layoffs` in schema `world_layoffs2` into MySQL Workbench 8.0
- Default settings of the import wizard have been used at that stage.
Output:
- The current script creates cleaned staging tables and produces a final cleaned table `layoffs_clean`, ready for analysis and BI.

Road Map:
0) Create a staging copy of the raw table (Raw table should never edited)
1) Standardization of text fields (trim, consistent labels, known spelling variants)
	1.1 Trim key text fields
    1.2 Normalizing selected categorical values
2) Parse and type-cast dates and numeric fields for analysis / BI (standardization)
3) De-duplication of records (Eliminate duplicates )
4) Consistent Handling of missing values (NULL vs empty strings)
	4.1 Populate missing industry by matching on company name using SELF JOIN
    4.2 Removing rows where BOTH key layoff metrics are missing (analytically useless rows)
5) Basic data quality checks (ranges, impossible values)
6) Common countries / industries inspection 
*/

USE world_layoffs2;

-- Used to ensure data integrity. 
-- If one statement between START TRANSACTION and COMIT failed, all statements will be dismissed.
START TRANSACTION;

-- ---------------------------------------------------------
-- 0) Create a staging copy of the raw table (Raw table should never edited)
-- ---------------------------------------------------------

DROP TABLE IF EXISTS layoffs_staging;
CREATE TABLE layoffs_staging LIKE layoffs;

INSERT INTO layoffs_staging
SELECT * FROM layoffs;

-- Quick sanity checks
SELECT COUNT(*) AS raw_row_count FROM layoffs;
SELECT COUNT(*) AS staging_row_count FROM layoffs_staging;

-- ---------------------------------------------------------------
-- 1) Standardization of text fields (trim, consistent labels, known spelling variants)
-- ---------------------------------------------------------------

-- 1.1 Trim key text fields (company name is the most common offender)
-- Trimm and set the value to NULL, if trimming result is blank
UPDATE layoffs_staging
SET company  = NULLIF(TRIM(company), ''),
    location = NULLIF(TRIM(location), ''),
    industry = NULLIF(TRIM(industry), ''),
    stage    = NULLIF(TRIM(stage), ''),
    country  = NULLIF(TRIM(country), '');

-- 1.2 Normalizing selected categorical values
-- Industry: unify Crypto labels
UPDATE layoffs_staging
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Location: unify Düsseldorf spelling to ASCII
UPDATE layoffs_staging
SET location = 'Dusseldorf'
WHERE location = 'Düsseldorf';

-- Country: remove trailing dot in "United States."
UPDATE layoffs_staging
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Stage: treat 'Unknown' as missing
UPDATE layoffs_staging
SET stage = NULL
WHERE stage = 'Unknown';

-- ----------------------------------------------------------
-- 2) Parse and type-cast dates and numeric fields for analysis / BI
-- ----------------------------------------------------------

-- Create a typed cleaned table and load standardized data
-- Most columns were defines as TEXT data type initially.
-- There are set to VARCHAR to be able to limit the number of character for efficiency.
DROP TABLE IF EXISTS layoffs_clean;

CREATE TABLE layoffs_clean (
  company                 VARCHAR(255)  NULL,
  location                VARCHAR(255)  NULL,
  industry                VARCHAR(255)  NULL,
  total_laid_off          INT           NULL,
  percentage_laid_off     DECIMAL(6,4)  NULL,  -- proportion from 0.0000 to 1.0000
  `date`                  DATE          NULL,
  stage                   VARCHAR(100)  NULL,
  country                 VARCHAR(255)  NULL,
  funds_raised_millions   DECIMAL(12,1) NULL   -- some values have decimal fractions (e.g., 156.5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Load data with safe casting/parsing
INSERT INTO layoffs_clean (
  company, location, industry,
  total_laid_off, percentage_laid_off,
  `date`, stage, country, funds_raised_millions
)
SELECT
  company,
  location,
  industry,
  -- total_laid_off is numeric in the CSV but sometimes lands as text depending on import settings
  CASE
    WHEN total_laid_off IS NULL THEN NULL
    WHEN total_laid_off < 0 THEN NULL
    ELSE CAST(total_laid_off AS SIGNED) -- cast from TEXT to a signed 64-bit integer
  END AS total_laid_off,
  -- percentage_laid_off should be a proportion [0,1]; null out impossible values
  CASE
    WHEN percentage_laid_off IS NULL THEN NULL
    WHEN percentage_laid_off < 0 OR percentage_laid_off > 1 THEN NULL
    ELSE CAST(percentage_laid_off AS DECIMAL(6,4))
  END AS percentage_laid_off,
  -- parse the text date like '3/6/2023' into a real DATE
  STR_TO_DATE(`date`, '%m/%d/%Y') AS `date`,
  stage,
  country,
  CASE
    WHEN funds_raised_millions IS NULL THEN NULL
    WHEN funds_raised_millions < 0 THEN NULL
    ELSE CAST(funds_raised_millions AS DECIMAL(12,1))
  END AS funds_raised_millions
FROM layoffs_staging;

-- ----------------------------------------------------
-- 3) De-duplication of records (Eliminate duplicates )
-- ----------------------------------------------------

/*
Strategy
- The window function ROW_NUMBER() is used to keep the first occurrence of each identical record
- The partition is made over all columns to define an unique row
*/

DROP TABLE IF EXISTS layoffs_dedup;

CREATE TABLE layoffs_dedup AS
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

-- Removing all rows from a table while keeping its structure, indexes, and constraints intact.
TRUNCATE TABLE layoffs_clean; 

-- Replace clean table with deduplicated version
INSERT INTO layoffs_clean
SELECT * FROM layoffs_dedup;

DROP TABLE IF EXISTS layoffs_dedup;

-- How many duplicates were removed?
SELECT
  (SELECT COUNT(*) FROM layoffs_staging) AS staging_rows_after_standardization,
  (SELECT COUNT(*) FROM layoffs_clean)    AS cleaned_rows_after_dedup;

-- -----------------------------------------------------
-- 4) Consistent Handling of missing values (NULL vs empty strings)
-- -----------------------------------------------------

-- 4.1 Populate missing industry by matching on company name using SELF JOIN
UPDATE layoffs_clean t1
JOIN layoffs_clean t2
  ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- 4.2 Removing rows where BOTH key layoff metrics are missing (analytically useless rows)
DELETE FROM layoffs_clean
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- ---------------------------------------------------------
-- 5) Basic data quality checks (ranges, impossible values)
-- ---------------------------------------------------------

-- Check for impossible percentage values
SELECT *
FROM layoffs_clean
WHERE percentage_laid_off < 0 OR percentage_laid_off > 1;

-- Check for negative totals
SELECT *
FROM layoffs_clean
WHERE total_laid_off < 0;

-- Check for dates that failed to parse (NULL dates)
SELECT COUNT(*) AS null_date_count
FROM layoffs_clean
WHERE `date` IS NULL;

-- Once occurence appears,  meaning that the source date format was different from '%m/%d/%Y' or just NULL
SELECT *
FROM layoffs_clean
WHERE `date` IS NULL;

-- ------------------------------------------------
-- 6) Most common countries / industries inspection
-- ------------------------------------------------

SELECT country, COUNT(*) AS n
FROM layoffs_clean
GROUP BY country
ORDER BY n DESC
LIMIT 20;

SELECT industry, COUNT(*) AS n
FROM layoffs_clean
GROUP BY industry
ORDER BY n DESC
LIMIT 20;


COMMIT;

-- Final preview
SELECT *
FROM layoffs_clean
LIMIT 50;

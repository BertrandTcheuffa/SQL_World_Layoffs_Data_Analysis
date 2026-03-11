/*
Layoffs dataset (2020–2023) — Exploratory Data Analysis (EDA)
Target: MySQL 8+

Road Map:
0) Row counts & Quick preview
1) Data quality checks
	1.1 Null profiling (how complete is the dataset?)
	1.2 Range and validity checks
	1.3 Duplicate check (It should be zero)
2) Dataset time coverage & high-level magnitude
	2.1 Date range
    2.2 Max layoff size & max percentage
3) Companies shutdown (percentage_laid_off = 1)
	3.1 Ordered by the most number of employees laid off
    3.2 Ordered by fundraising, to identify well-funded companies that totally failed.
4) Total layoffs ordered by key business dimensions
	4.1 By company
    4.2 By industry
    4.3 By country
    4.4 By stage
5) Trend analysis over time (monthly + rolling total)
	5.1 Monthly layoff's total (calendar month)
    5.2 Rolling cumulative total
    5.3 Month-over-month change to spot spikes
6) Yearly totals:  which year was the worst?
7) Company layoffs per year + top-N ranking per year
	7.1 Company-year totals
    7.2 Top 5 companies by layoffs per year
8) More Business-relevant EDA
	8.1 Country trend: monthly total layoffs of top 10 countries
    8.2 Severity buckets classification
    8.3 Funding vs layoff size
*/

USE world_layoffs2;

-- Since the EDA runs locally, there is no need for session isolation.
START TRANSACTION;

-- 0) Row counts & Quick preview

SELECT COUNT(*) AS row_count FROM layoffs_clean;

SELECT *
FROM layoffs_clean
LIMIT 25;

-- 1) Data quality checks

-- 1.1 Null profiling (how complete is the dataset?)
SELECT
  SUM(company IS NULL)                  AS null_company,
  SUM(location IS NULL)                 AS null_location,
  SUM(industry IS NULL)                 AS null_industry,
  SUM(total_laid_off IS NULL)           AS null_total_laid_off,
  SUM(percentage_laid_off IS NULL)      AS null_percentage_laid_off,
  SUM(`date` IS NULL)                   AS null_date,
  SUM(stage IS NULL)                    AS null_stage,
  SUM(country IS NULL)                  AS null_country,
  SUM(funds_raised_millions IS NULL)    AS null_funds_raised_millions
FROM layoffs_clean;

-- 1.2 Range and validity checks
-- percentage_laid_off should be in [0,1] when present
SELECT *
FROM layoffs_clean
WHERE percentage_laid_off IS NOT NULL
  AND (percentage_laid_off < 0 OR percentage_laid_off > 1)
LIMIT 50;

-- total_laid_off should be non-negative when present
SELECT *
FROM layoffs_clean
WHERE total_laid_off IS NOT NULL
  AND total_laid_off < 0
LIMIT 50;

-- funds_raised_millions should be non-negative when present
SELECT *
FROM layoffs_clean
WHERE funds_raised_millions IS NOT NULL
  AND funds_raised_millions < 0
LIMIT 50;

-- 1.3 Duplicate check (It should be zero)

WITH dup_cte AS (
  SELECT
    company, location, industry,
    total_laid_off, percentage_laid_off,
    `date`, stage, country, funds_raised_millions,
    COUNT(*) AS cnt
  FROM layoffs_clean
  GROUP BY
    company, location, industry,
    total_laid_off, percentage_laid_off,
    `date`, stage, country, funds_raised_millions
  HAVING COUNT(*) > 1
)
SELECT *
FROM dup_cte
ORDER BY cnt DESC, company
LIMIT 50;

-- 2) Dataset time coverage & high-level magnitude

-- 2.1 Date range
SELECT
  MIN(`date`) AS min_date,
  MAX(`date`) AS max_date
FROM layoffs_clean;

-- 2.2 Max layoff size & max percentage
SELECT
  MAX(total_laid_off)      AS max_total_laid_off,
  MAX(percentage_laid_off) AS max_percentage_laid_off
FROM layoffs_clean;

-- 3) Examinate companies shutdown (percentage_laid_off = 1)

-- 3.1 Ordered by the most number of employees laid off
SELECT *
FROM layoffs_clean
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC
LIMIT 50;

-- 3.2 Ordered by fundraising, to identify well-funded companies that totally failed.
SELECT *
FROM layoffs_clean
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC
LIMIT 50;

-- 4) Total layoffs by key business dimensions

-- 4.1 By company
SELECT
  company,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE total_laid_off IS NOT NULL
GROUP BY company
ORDER BY total_laid_off DESC
LIMIT 50;

-- 4.2 By industry
SELECT
  industry,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE total_laid_off IS NOT NULL
GROUP BY industry
ORDER BY total_laid_off DESC
LIMIT 50;

-- 4.3 By country
SELECT
  country,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE total_laid_off IS NOT NULL
GROUP BY country
ORDER BY total_laid_off DESC
LIMIT 50;

-- 4.4 By stage
SELECT
  stage,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE total_laid_off IS NOT NULL
GROUP BY stage
ORDER BY total_laid_off DESC
LIMIT 50;

-- -----------------------------------------------------
-- 5) Trend analysis over time (monthly + rolling total)
-- -----------------------------------------------------

-- 5.1 Monthly layoff's totals (calendar month)
SELECT
  DATE_FORMAT(`date`, '%Y-%m') AS `month`,
  SUM(total_laid_off) AS monthly_total_laid_off
FROM layoffs_clean
WHERE `date` IS NOT NULL
  AND total_laid_off IS NOT NULL
GROUP BY DATE_FORMAT(`date`, '%Y-%m')
ORDER BY `month` ASC;

-- 5.2 Rolling cumulative total
WITH monthly_layoffs_cte AS (
  SELECT
    DATE_FORMAT(`date`, '%Y-%m') AS `month`,
    SUM(total_laid_off) AS monthly_total_laid_off -- Summe of employees laid off by month
  FROM layoffs_clean
  WHERE `date` IS NOT NULL
    AND total_laid_off IS NOT NULL
  GROUP BY DATE_FORMAT(`date`, '%Y-%m') -- Grouping by month to perform the aggregate function SUM()
)
SELECT
  `month`,
  monthly_total_laid_off,
  SUM(monthly_total_laid_off) OVER (ORDER BY `month`) AS rolling_total_laid_off -- Uses window function SUM() OVER() to perform rolling total
FROM monthly_layoffs_cte
ORDER BY `month` ASC;

-- 5.3 Month-over-month change to spot spikes
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

-- 6) Yearly totals:  which year was the worst?

SELECT
  YEAR(`date`) AS `year`,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE `date` IS NOT NULL
  AND total_laid_off IS NOT NULL
GROUP BY YEAR(`date`)
ORDER BY `year` ASC;

-- -----------------------------------------------------
-- 7) Company layoffs per year + top-N ranking per year
-- -----------------------------------------------------

-- 7.1 Company-year totals
SELECT
  company,
  YEAR(`date`) AS `year`,
  SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE `date` IS NOT NULL
  AND total_laid_off IS NOT NULL
GROUP BY company, YEAR(`date`)
ORDER BY total_laid_off DESC;

-- 7.2 Top 5 companies by layoffs per year
WITH company_year_cte AS (
-- CTE for the total layoffs per year and company
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

-- --------------------------------------------------------------
-- 8) More Business-relevant EDA
-- --------------------------------------------------------------

-- 8.1 Country trend: monthly total layoffs of top 10 countries
WITH top_10_countries AS (
-- Ranking the 10 countries with the most layoffs
  SELECT country
  FROM layoffs_clean
  WHERE total_laid_off IS NOT NULL
  GROUP BY country
  ORDER BY SUM(total_laid_off) DESC
  LIMIT 10
)
SELECT
  DATE_FORMAT(lc.`date`, '%Y-%m') AS `month`,
  lc.country,
  SUM(lc.total_laid_off) AS monthly_total_laid_off
FROM layoffs_clean AS lc
JOIN top_10_countries AS tc
  ON lc.country = tc.country
WHERE lc.`date` IS NOT NULL
  AND lc.total_laid_off IS NOT NULL
GROUP BY `month`, lc.country
ORDER BY `month` ASC, monthly_total_laid_off DESC;

-- 8.2 Severity buckets classification
-- Buckets are based on percentage laid off, when they are available.
SELECT
  CASE
    WHEN percentage_laid_off IS NULL THEN 'Unknown %'
    WHEN percentage_laid_off = 1 THEN '100%'
    WHEN percentage_laid_off >= 0.50 THEN '50%–99%'
    WHEN percentage_laid_off >= 0.20 THEN '20%–49%'
    WHEN percentage_laid_off > 0 THEN '1%–19%'
    ELSE '0%'
  END AS layoff_severity_bucket,
  COUNT(*) AS events,
  SUM(COALESCE(total_laid_off, 0)) AS total_people_laid_off -- if total_laid_off is not NULL, COALESCE() return total_laid_off, otherwise 0
FROM layoffs_clean
GROUP BY layoff_severity_bucket
ORDER BY total_people_laid_off DESC;

-- 8.3 Funding vs layoff size
-- Creates funding bands and summarizes layoff magnitude.
SELECT
  CASE
    WHEN funds_raised_millions IS NULL THEN 'Unknown funding'
    WHEN funds_raised_millions < 10 THEN '<$10M'
    WHEN funds_raised_millions < 50 THEN '$10M–$49M'
    WHEN funds_raised_millions < 200 THEN '$50M–$199M'
    WHEN funds_raised_millions < 1000 THEN '$200M–$999M'
    ELSE '$1B+'
  END AS funding_band,
  COUNT(*) AS events,
  SUM(COALESCE(total_laid_off, 0)) AS total_people_laid_off,
  AVG(total_laid_off) AS avg_total_laid_off,
  AVG(percentage_laid_off) AS avg_percentage_laid_off
FROM layoffs_clean
GROUP BY funding_band
ORDER BY total_people_laid_off DESC;

COMMIT;
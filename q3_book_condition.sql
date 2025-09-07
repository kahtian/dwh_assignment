-- ===================================================================================
-- query 3: Book Condition and Damage Analysis
-- Information Need: To analyze loan patterns by year and season, identifying when
-- books with current 'FAIR' or 'POOR' conditions were most heavily used, and which
-- book categories contribute most to damage in specific periods.
-- This helps answer "When do we see the highest damage rates?" and "Which categories
-- are most problematic during high-stress periods?"
-- ===================================================================================

-- Clear previous settings
-- CLEAR SCREEN
CLEAR BREAKS
CLEAR COMPUTES
CLEAR COLUMNS
SET VERIFY OFF
SET FEEDBACK OFF
SET PAGESIZE 50
SET LINESIZE 80

-- ===================================================================================
-- User Input
-- ===================================================================================
PROMPT
PROMPT Please provide the analysis period for the Book Damage Report.
ACCEPT start_year_prompt CHAR PROMPT 'Enter Start Year (e.g., 2016): '
ACCEPT end_year_prompt CHAR PROMPT 'Enter End Year (e.g., 2025): '
PROMPT

-- ===================================================================================
-- Report 1: Year/Season Breakdown with Damage Analysis
-- ===================================================================================
TTITLE CENTER '=====================================================' SKIP 1 -
       CENTER 'Loan Damage Analysis by Year and Season' SKIP 1 -
       CENTER 'For Years &start_year_prompt to &end_year_prompt' SKIP 1 -
       CENTER '=====================================================' SKIP 1 -
       LEFT 'Report Generated on: ' _DATE  -
       RIGHT 'Page: ' SQL.PNO SKIP 2

COLUMN loan_year FORMAT 9999 HEADING 'Year'
COLUMN season FORMAT A12 HEADING 'Season'
COLUMN total_loans FORMAT 999,999 HEADING 'Total|Loans'
COLUMN pct_fair_loans FORMAT A10 HEADING '% Fair|Loans'
COLUMN pct_poor_loans FORMAT A10 HEADING '% Poor|Loans'
COLUMN pct_of_year_loans FORMAT A12 HEADING '% of Year''s|Loans'

BREAK ON loan_year SKIP 1
COMPUTE SUM LABEL 'Year Total:' OF total_loans ON loan_year

WITH
-- Step 1: Analyze all loans within the period, categorizing by current book condition
LOAN_DAMAGE_ANALYSIS AS (
    SELECT
        dd.cal_year AS loan_year,
        CASE
            WHEN dd.EXAM_WEEK_IND = 'Y' THEN 'Exam Week'
            WHEN dd.STUDY_WEEK_IND = 'Y' THEN 'Study Week'
            WHEN dd.HOLIDAY_IND = 'Y' THEN 'Holiday'
            ELSE 'Regular'
        END AS season,
        COUNT(*) AS total_loans,
        SUM(CASE WHEN bd.bookCondition = 'FAIR' THEN 1 ELSE 0 END) AS fair_loans,
        SUM(CASE WHEN bd.bookCondition = 'POOR' THEN 1 ELSE 0 END) AS poor_loans
    FROM LOAN_FACT lf
    JOIN DATE_DIM dd ON lf.date_key = dd.date_key
    JOIN BOOK_DIM bd ON lf.book_key = bd.book_key
    WHERE dd.cal_year BETWEEN '&start_year_prompt' AND '&end_year_prompt'
    GROUP BY dd.cal_year, 
             CASE
                 WHEN dd.EXAM_WEEK_IND = 'Y' THEN 'Exam Week'
                 WHEN dd.STUDY_WEEK_IND = 'Y' THEN 'Study Week'
                 WHEN dd.HOLIDAY_IND = 'Y' THEN 'Holiday'
                 ELSE 'Regular'
             END
),
-- Step 2: Calculate year totals for percentage calculations
YEAR_TOTALS AS (
    SELECT
        loan_year,
        SUM(total_loans) AS year_total_loans
    FROM LOAN_DAMAGE_ANALYSIS
    GROUP BY loan_year
)
-- Step 3: Generate the final report with all percentages
SELECT
    lda.loan_year,
    lda.season,
    lda.total_loans,
    TO_CHAR(ROUND((lda.fair_loans * 100.0 / lda.total_loans), 1), '990.9') || '%' AS pct_fair_loans,
    TO_CHAR(ROUND((lda.poor_loans * 100.0 / lda.total_loans), 1), '990.9') || '%' AS pct_poor_loans,
    TO_CHAR(ROUND((lda.total_loans * 100.0 / yt.year_total_loans), 1), '990.9') || '%' AS pct_of_year_loans
FROM LOAN_DAMAGE_ANALYSIS lda
JOIN YEAR_TOTALS yt ON lda.loan_year = yt.loan_year
ORDER BY lda.loan_year, lda.total_loans DESC;

CLEAR BREAKS
CLEAR COMPUTES

-- ===================================================================================
-- Report 2: Interactive Drill-Down by Category
-- ===================================================================================
-- PROMPT
-- PROMPT
-- PROMPT =================================================================
-- PROMPT Drill-Down Analysis by Book Category for a Specific Year/Season
-- PROMPT =================================================================
-- PROMPT

ACCEPT drilldown_year_prompt CHAR PROMPT 'Enter Year to Drill Down (e.g., 2020): '
ACCEPT drilldown_season_prompt CHAR PROMPT 'Enter Season to Drill Down (Exam Week/Study Week/Holiday/Regular): '

TTITLE CENTER '=====================================================' SKIP 1 -
       CENTER 'Category Damage Analysis for &drilldown_season_prompt &drilldown_year_prompt' SKIP 1 -
       CENTER '=====================================================' SKIP 2

COLUMN book_category FORMAT A20 HEADING 'Book Category'
COLUMN fair_books_loaned FORMAT 999,999 HEADING 'Fair Books|Loaned'
COLUMN poor_books_loaned FORMAT 999,999 HEADING 'Poor Books|Loaned'
COLUMN total_category_loans FORMAT 999,999 HEADING 'Total Category|Loans'
COLUMN damage_rate FORMAT A12 HEADING 'Damage Rate|%'

BREAK ON REPORT
COMPUTE AVG LABEL 'Overall Avg:' OF damage_rate ON REPORT

WITH
CATEGORY_DAMAGE_ANALYSIS AS (
    SELECT
        bd.bookCategory,
        SUM(CASE WHEN bd.bookCondition = 'FAIR' THEN 1 ELSE 0 END) AS fair_books_loaned,
        SUM(CASE WHEN bd.bookCondition = 'POOR' THEN 1 ELSE 0 END) AS poor_books_loaned,
        COUNT(*) AS total_category_loans
    FROM LOAN_FACT lf
    JOIN DATE_DIM dd ON lf.date_key = dd.date_key
    JOIN BOOK_DIM bd ON lf.book_key = bd.book_key
    WHERE dd.cal_year = '&drilldown_year_prompt'
      AND CASE
              WHEN dd.EXAM_WEEK_IND = 'Y' THEN 'EXAM WEEK'
              WHEN dd.STUDY_WEEK_IND = 'Y' THEN 'STUDY WEEK'
              WHEN dd.HOLIDAY_IND = 'Y' THEN 'HOLIDAY'
              ELSE 'REGULAR'
          END = UPPER('&drilldown_season_prompt')
    GROUP BY bd.bookCategory
)
SELECT
    bookCategory AS book_category,
    fair_books_loaned,
    poor_books_loaned,
    total_category_loans,
    TO_CHAR(ROUND(((fair_books_loaned + poor_books_loaned) * 100.0 / total_category_loans), 1), '990.9') || '%' AS damage_rate
FROM CATEGORY_DAMAGE_ANALYSIS
WHERE total_category_loans > 0
ORDER BY damage_rate DESC;

-- Final cleanup
CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES
UNDEFINE start_year_prompt
UNDEFINE end_year_prompt
UNDEFINE drilldown_year_prompt
UNDEFINE drilldown_season_prompt
SET FEEDBACK ON
SET VERIFY ON
TTITLE OFF
PROMPT
PROMPT Report complete.

PROMPT

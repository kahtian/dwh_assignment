-- query 1: Annual Customer Value (ACV) & Segmentation Analysis
-- Information Need: To identify our most valuable customers based on their total spending and loan activity on an annual basis. 
-- allow user input to define the time period for the analysis.
-- This helps answer "who should we loan / sell books to?".
-- Flexible Query: This report combines data from sales_fact and loan_fact. 
-- It calculates annual value for each member by summing orderTotalPrice and totalFine. Members are then segmented into tiers (e.g., Platinum, Gold, Silver, Bronze) based on their annual value. 
-- The analysis uses member_dim for customer details and date_dim to track value over time.
-- Show the results in a table with the following columns: Tier, year, % of total members, avg clv, % of tier at risk (become less active compared to previous year).
-- break on tier.

-- ===================================================================================
-- SQL*Plus Report Formatting
-- ===================================================================================
-- A4 Paper Size Formatting
SET PAGESIZE 50
SET LINESIZE 80
SET FEEDBACK OFF -- Hide the "X rows selected" message

-- Clear any previous formatting rules
CLEAR BREAKS
CLEAR COMPUTES

-- Define column formats for better readability
COLUMN tier FORMAT A10 HEADING 'Tier'
COLUMN year FORMAT 9999 HEADING 'Year'
COLUMN pct_total_members FORMAT A15 HEADING '% of |Total Members'
COLUMN avg_clv FORMAT 999,990.99 HEADING 'Avg CLV (RM)'
COLUMN pct_tier_at_risk FORMAT A15 HEADING '% of |Tier at Risk'

-- Set up report breaks and computations
-- This creates a summary line for each tier
BREAK ON tier SKIP 1

-- This will compute the average CLV for all members within a tier over the selected years
COMPUTE AVG LABEL 'Tier Avg CLV:' OF avg_clv ON tier

-- ===================================================================================
-- User Input
-- ===================================================================================
PROMPT
PROMPT Please provide the analysis period for the CLV Report.
ACCEPT start_year_prompt CHAR PROMPT 'Enter Start Year (e.g., 2016): '
ACCEPT end_year_prompt CHAR PROMPT 'Enter End Year (e.g., 2025): '
PROMPT

-- ===================================================================================
-- ACV and Customer Segmentation Report
-- ===================================================================================
WITH
-- Step 1: Aggregate annual sales and fines for each member.
-- A FULL OUTER JOIN ensures we capture members who may only have loans or only have sales in a given year.
MEMBER_ANNUAL_VALUE AS (
    SELECT
        COALESCE(s.member_key, l.member_key) AS member_key,
        COALESCE(s.cal_year, l.cal_year) AS cal_year,
        NVL(s.total_sales, 0) AS total_sales,
        NVL(l.total_fines, 0) AS total_fines,
        (NVL(s.total_sales, 0) + NVL(l.total_fines, 0)) AS annual_clv
    FROM
        ( -- Annual sales per member
            SELECT
                sf.member_key,
                dd.cal_year,
                SUM(sf.orderTotalPrice) AS total_sales
            FROM SALES_FACT sf
            JOIN DATE_DIM dd ON sf.date_key = dd.date_key
            GROUP BY sf.member_key, dd.cal_year
        ) s
    FULL OUTER JOIN
        ( -- Annual fines per member
            SELECT
                lf.member_key,
                dd.cal_year,
                SUM(lf.totalFine) AS total_fines
            FROM LOAN_FACT lf
            JOIN DATE_DIM dd ON lf.date_key = dd.date_key
            WHERE lf.totalFine > 0
            GROUP BY lf.member_key, dd.cal_year
        ) l ON s.member_key = l.member_key AND s.cal_year = l.cal_year
),
-- Step 2: Determine annual tier and risk status year-over-year.
MEMBER_ANNUAL_TIERS AS (
    SELECT
        mav.member_key,
        mav.cal_year,
        mav.annual_clv,
        -- Check if current year's value is less than the previous year's. LAG() is used to look back one year.
        CASE
            WHEN mav.annual_clv < LAG(mav.annual_clv, 1, 0) OVER (PARTITION BY mav.member_key ORDER BY mav.cal_year)
            THEN 1
            ELSE 0
        END AS is_at_risk,
        -- Assign tiers based on the ANNUAL value. Thresholds are adjusted for annual vs lifetime.
        CASE
            WHEN mav.annual_clv >= 150 THEN 'Platinum'
            WHEN mav.annual_clv >= 75 THEN 'Gold'
            WHEN mav.annual_clv >= 25 THEN 'Silver'
            ELSE 'Bronze'
        END AS tier
    FROM MEMBER_ANNUAL_VALUE mav
),
-- Step 3: Aggregate the results by tier and year for the final report.
ANNUAL_TIER_SUMMARY AS (
    SELECT
        tier,
        cal_year,
        COUNT(DISTINCT member_key) AS member_count,
        AVG(annual_clv) AS avg_clv,
        SUM(is_at_risk) AS at_risk_count
    FROM MEMBER_ANNUAL_TIERS
    -- Filter data based on the user's input
    WHERE cal_year BETWEEN TO_NUMBER('&start_year_prompt') AND TO_NUMBER('&end_year_prompt')
    GROUP BY tier, cal_year
),
-- Step 4: Calculate final percentages using window functions for totals.
FINAL_REPORT AS (
    SELECT
        ats.tier,
        ats.cal_year AS year,
        ats.member_count,
        ats.avg_clv,
        ats.at_risk_count,
        -- Get total members for the year to calculate the denominator for the percentage.
        SUM(ats.member_count) OVER (PARTITION BY ats.cal_year) AS total_members_in_year
    FROM ANNUAL_TIER_SUMMARY ats
)
-- Final presentation query to format the output as requested.
SELECT
    fr.tier,
    fr.year,
    TO_CHAR(ROUND((fr.member_count * 100.0 / fr.total_members_in_year), 2), '990.99MI') || '%' AS pct_total_members,
    ROUND(fr.avg_clv, 2) AS avg_clv,
    TO_CHAR(ROUND((fr.at_risk_count * 100.0 / fr.member_count), 2), '990.99MI') || '%' AS pct_tier_at_risk
FROM FINAL_REPORT fr
ORDER BY
    -- Custom order for tiers
    CASE fr.tier
        WHEN 'Platinum' THEN 1
        WHEN 'Gold' THEN 2
        WHEN 'Silver' THEN 3
        WHEN 'Bronze' THEN 4
    END,
    fr.year;

-- ===================================================================================
-- Cleanup
-- ===================================================================================
-- Clear user-defined variables and reset formatting to default
UNDEFINE start_year_prompt
UNDEFINE end_year_prompt
CLEAR BREAKS
CLEAR COMPUTES
CLEAR COLUMNS
SET FEEDBACK ON
PROMPT Report complete.
PROMPT
-- query 1: Annual Customer Value (ACV) & Segmentation Analysis
-- Information Need: To identify our most valuable customers based on their total spending and loan activity on an annual basis. 
-- allow user input to define the time period for the analysis.
-- This helps answer "who should we loan / sell books to?".
-- Flexible Query: This report combines data from sales_fact and loan_fact. 
-- It calculates annual value for each member by summing orderTotalPrice and totalFine. Members are then segmented into tiers (e.g., Platinum, Gold, Silver, Bronze) based on their annual value. 
-- The analysis uses member_dim for customer details and date_dim to track value over time.
-- Show the results in a table with the following columns: Tier, year, % of total members, avg clv, % of tier at risk (become less active compared to previous year).
-- ADDITION: Include a second, drill-down report that analyzes a specific tier/year by member age group.
-- break on tier.

-- Clear previous settings
CLEAR SCREEN
CLEAR BREAKS
CLEAR COMPUTES
CLEAR COLUMNS
SET VERIFY OFF
SET FEEDBACK OFF
SET PAGESIZE 50
SET LINESIZE 80
-- A4 Paper Size Formatting

TTITLE ON
TTITLE CENTER '=====================================================' SKIP 1 -
       CENTER 'Annual Customer Value (ACV) and Segmentation Analysis' SKIP 1 -
       CENTER '=====================================================' SKIP 1 -
       LEFT 'Report Generated on: ' _DATE  -
       RIGHT 'Page: ' SQL.PNO SKIP 2

-- Define column formats for better readability
COLUMN tier FORMAT A15 HEADING 'Tier'
COLUMN year FORMAT 9999 HEADING 'Year'
COLUMN pct_total_members FORMAT A20 HEADING '% of Total Members'
COLUMN avg_acv FORMAT 999,990.99 HEADING 'Avg ACV (RM)'
COLUMN pct_tier_at_risk FORMAT A20 HEADING '% of Tier at Risk'

-- Set up report breaks and computations
-- This creates a summary line for each tier
BREAK ON tier SKIP 1

-- This will compute the average ACV for all members within a tier over the selected years
COMPUTE AVG LABEL 'Tier Avg ACV:' OF avg_acv ON tier

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
        -- Calculate the annual customer value (ACV)
        NVL(s.total_sales, 0) + NVL(l.total_fines, 0) AS annual_acv
    FROM
        (
            -- Aggregate total sales per member per year
            SELECT
                sf.member_key,
                dd.cal_year,
                SUM(sf.orderTotalPrice) AS total_sales
            FROM SALES_FACT sf
            JOIN DATE_DIM dd ON sf.date_key = dd.date_key
            GROUP BY sf.member_key, dd.cal_year
        ) s
    FULL OUTER JOIN
        (
            -- Aggregate total fines per member per year
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
-- Step 2: Rank members into percentiles for each year and determine at-risk status.
MEMBER_ANNUAL_TIERS_WITH_RANK AS (
    SELECT
        mav.member_key,
        mav.cal_year,
        mav.annual_acv,
        -- Check if current year's value is less than the previous year's.
        CASE
            WHEN mav.annual_acv < LAG(mav.annual_acv, 1, 0) OVER (PARTITION BY mav.member_key ORDER BY mav.cal_year)
            THEN 1
            ELSE 0
        END AS is_at_risk,
        -- Use NTILE to create 10 percentile groups (deciles) for each year.
        -- We order by ACV descending, so group 1 is the top 10%.
        NTILE(10) OVER (PARTITION BY mav.cal_year ORDER BY mav.annual_acv DESC) AS percentile_rank
    FROM MEMBER_ANNUAL_VALUE mav
),
-- Step 3: Aggregate the results by tier and year for the final report.
ANNUAL_TIER_SUMMARY AS (
    SELECT
        -- Assign tiers based on the percentile rank. This is a robust, data-driven approach.
        CASE
            WHEN percentile_rank = 1 THEN 'Platinum' -- Top 10%
            WHEN percentile_rank BETWEEN 2 AND 3 THEN 'Gold'     -- Next 20%
            WHEN percentile_rank BETWEEN 4 AND 6 THEN 'Silver'   -- Next 30%
            ELSE 'Bronze'                                        -- Bottom 40%
        END AS tier,
        cal_year,
        COUNT(DISTINCT member_key) AS member_count,
        AVG(annual_acv) AS avg_acv,
        SUM(is_at_risk) AS at_risk_count
    FROM MEMBER_ANNUAL_TIERS_WITH_RANK
    -- Filter data based on the user's input
    WHERE cal_year BETWEEN TO_NUMBER('&start_year_prompt') AND TO_NUMBER('&end_year_prompt')
    GROUP BY
        CASE
            WHEN percentile_rank = 1 THEN 'Platinum' -- Top 10%
            WHEN percentile_rank BETWEEN 2 AND 3 THEN 'Gold'     -- Next 20%
            WHEN percentile_rank BETWEEN 4 AND 6 THEN 'Silver'   -- Next 30%
            ELSE 'Bronze'                                        -- Bottom 40%
        END,
        cal_year
),
-- Step 4: Calculate final percentages using window functions for totals.
FINAL_REPORT AS (
    SELECT
        ats.tier,
        ats.cal_year AS year,
        ats.member_count,
        ats.avg_acv,
        ats.at_risk_count,
        -- Use a window function to get the total number of members for each year to calculate percentages.
        SUM(ats.member_count) OVER (PARTITION BY ats.cal_year) AS total_members_in_year
    FROM ANNUAL_TIER_SUMMARY ats
)
-- Final presentation query to format the output as requested.
SELECT
    fr.tier,
    fr.year,
    TO_CHAR(ROUND((fr.member_count * 100.0 / fr.total_members_in_year), 2), '990.99MI') || '%' AS pct_total_members,
    ROUND(fr.avg_acv, 2) AS avg_acv,
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

-- Clear settings from the first report
CLEAR COMPUTES
CLEAR BREAKS
CLEAR COLUMNS

-- ===================================================================================
-- Drill-Down Report by Age Group
-- ===================================================================================
PROMPT
PROMPT
PROMPT =================================================================
PROMPT Drill-Down Analysis by Age Group for a Specific Tier and Year
PROMPT =================================================================
PROMPT

ACCEPT drilldown_year_prompt CHAR PROMPT 'Enter Year to Drill Down (e.g., 2023): '
ACCEPT drilldown_tier_prompt CHAR PROMPT 'Enter Tier to Drill Down (e.g., Gold): '

-- Set title for the drill-down report
TTITLE CENTER 'Drill-Down Analysis for &drilldown_tier_prompt Tier in &drilldown_year_prompt by Age Group' SKIP 2

-- Define column formats for the drill-down report
COLUMN age_group FORMAT A10 HEADING 'Age Group'
COLUMN member_count_drilldown FORMAT 999,999 HEADING 'Member Count'
COLUMN pct_of_tier FORMAT A20 HEADING '% of Tier Members'
COLUMN avg_acv_age_group FORMAT '999,990.99' HEADING 'Avg ACV (RM)'
COLUMN pct_at_risk_age_group FORMAT A15 HEADING '% At Risk'

-- Re-run the core logic, but this time join with MEMBER_DIM to get age groups
-- and filter for the specific tier/year provided by the user.
WITH
MEMBER_ANNUAL_VALUE AS (
    SELECT
        COALESCE(s.member_key, l.member_key) AS member_key,
        COALESCE(s.cal_year, l.cal_year) AS cal_year,
        NVL(s.total_sales, 0) + NVL(l.total_fines, 0) AS annual_acv
    FROM
        (SELECT sf.member_key, dd.cal_year, SUM(sf.orderTotalPrice) AS total_sales FROM SALES_FACT sf JOIN DATE_DIM dd ON sf.date_key = dd.date_key GROUP BY sf.member_key, dd.cal_year) s
    FULL OUTER JOIN
        (SELECT lf.member_key, dd.cal_year, SUM(lf.totalFine) AS total_fines FROM LOAN_FACT lf JOIN DATE_DIM dd ON lf.date_key = dd.date_key GROUP BY lf.member_key, dd.cal_year) l
        ON s.member_key = l.member_key AND s.cal_year = l.cal_year
),
-- Replicating the same percentile-based tiering logic for the drill-down to ensure consistency.
MEMBER_ANNUAL_TIERS_WITH_RANK AS (
    SELECT
        mav.member_key,
        mav.cal_year,
        mav.annual_acv,
        CASE WHEN mav.annual_acv < LAG(mav.annual_acv, 1, 0) OVER (PARTITION BY mav.member_key ORDER BY mav.cal_year) THEN 1 ELSE 0 END AS is_at_risk,
        NTILE(10) OVER (PARTITION BY mav.cal_year ORDER BY mav.annual_acv DESC) AS percentile_rank
    FROM MEMBER_ANNUAL_VALUE mav
),
MEMBER_ANNUAL_TIERS AS (
    SELECT
        r.*,
        CASE
            WHEN r.percentile_rank = 1 THEN 'Platinum' -- Top 10%
            WHEN r.percentile_rank BETWEEN 2 AND 3 THEN 'Gold'     -- Next 20%
            WHEN r.percentile_rank BETWEEN 4 AND 6 THEN 'Silver'   -- Next 30%
            ELSE 'Bronze'                                        -- Bottom 40%
        END AS tier
    FROM MEMBER_ANNUAL_TIERS_WITH_RANK r
),
DRILLDOWN_AGE_ANALYSIS AS (
    SELECT
        mat.annual_acv,
        mat.is_at_risk,
        CASE
            WHEN TRUNC((TO_DATE(mat.cal_year || '-12-31', 'YYYY-MM-DD') - md.dob) / 365.25) <= 25 THEN '18-25'
            WHEN TRUNC((TO_DATE(mat.cal_year || '-12-31', 'YYYY-MM-DD') - md.dob) / 365.25) <= 35 THEN '26-35'
            WHEN TRUNC((TO_DATE(mat.cal_year || '-12-31', 'YYYY-MM-DD') - md.dob) / 365.25) <= 45 THEN '36-45'
            WHEN TRUNC((TO_DATE(mat.cal_year || '-12-31', 'YYYY-MM-DD') - md.dob) / 365.25) > 45 THEN '46+'
            ELSE 'Unknown'
        END AS age_group
    FROM MEMBER_ANNUAL_TIERS mat
    -- FIX: This is now a point-in-time join to get the member's details as they were in that specific year.
    JOIN MEMBER_DIM md ON mat.member_key = md.member_key
        AND TO_DATE(mat.cal_year || '-01-01', 'YYYY-MM-DD') BETWEEN md.effective_start_date AND md.effective_end_date
    WHERE mat.cal_year = TO_NUMBER('&drilldown_year_prompt')
      AND UPPER(mat.tier) = UPPER('&drilldown_tier_prompt')
),
DRILLDOWN_SUMMARY AS (
    SELECT
        age_group,
        COUNT(*) AS member_count_drilldown,
        AVG(annual_acv) AS avg_acv_age_group,
        SUM(is_at_risk) AS at_risk_count,
        SUM(COUNT(*)) OVER () as total_tier_members
    FROM DRILLDOWN_AGE_ANALYSIS
    GROUP BY age_group
)
SELECT
    age_group,
    member_count_drilldown,
    TO_CHAR(ROUND((member_count_drilldown * 100.0 / total_tier_members), 2), '990.99MI') || '%' AS pct_of_tier,
    avg_acv_age_group,
    CASE WHEN member_count_drilldown > 0 THEN TO_CHAR(ROUND((at_risk_count * 100.0 / member_count_drilldown), 2), '990.99MI') || '%' ELSE '0.00%' END AS pct_at_risk_age_group
FROM DRILLDOWN_SUMMARY
ORDER BY age_group;


-- Final cleanup
CLEAR COLUMNS
-- Clear user-defined variables and reset formatting to default
UNDEFINE start_year_prompt
UNDEFINE end_year_prompt
CLEAR BREAKS
CLEAR COMPUTES
SET FEEDBACK ON
TTITLE OFF
PROMPT Report complete.
PROMPT
-- ===================================================================================
-- query 2: Geographic Hotspot Analysis with Interactive Drill-Down (View-Based)
-- Information Need: To get a high-level overview of performance by state, and then
-- optionally drill down to see a detailed breakdown by city for a specific state.
-- This helps answer "Which regions are performing well?" and then "Which cities
-- are driving that performance?"
--
-- Flexible Query: This report uses a temporary view to simplify the logic for two
-- separate reports (state summary and city drill-down). The view is created at the
-- start and dropped at the end.
-- ===================================================================================

-- Clear previous settings
CLEAR SCREEN
SET VERIFY OFF
SET FEEDBACK OFF
SET PAGESIZE 50 
SET LINESIZE 80
-- ===================================================================================
-- User Prompts & View Creation
-- ===================================================================================
ACCEPT start_year_prompt CHAR PROMPT 'Enter Start Year for Analysis (e.g., 2016): '
ACCEPT end_year_prompt CHAR PROMPT 'Enter End Year for Analysis (e.g., 2025): '
PROMPT

PROMPT Creating temporary view for analysis...

-- Create a view to hold the core logic. 
CREATE OR REPLACE VIEW GEO_CITY_PERFORMANCE_V AS
SELECT
    md.memberState,
    md.memberCity,
    SUM(sf.orderTotalPrice) AS sales_in_geo,
    COUNT(DISTINCT sf.member_key) AS members_in_geo
FROM SALES_FACT sf
-- The join to DATE_DIM is needed to get the actual date of the transaction
JOIN DATE_DIM dd ON sf.date_key = dd.date_key
-- This is the crucial point-in-time join to MEMBER_DIM
JOIN MEMBER_DIM md ON sf.member_key = md.member_key
    AND dd.CAL_DATE >= md.effective_start_date 
    AND dd.CAL_DATE <= md.effective_end_date
WHERE
    dd.cal_year BETWEEN TO_NUMBER('&start_year_prompt') AND TO_NUMBER('&end_year_prompt')
GROUP BY
    md.memberState,
    md.memberCity;

PROMPT View created. Generating reports...
PROMPT

-- Report 1: State-Level Summary
TTITLE CENTER '=====================================================' SKIP 1 -
       CENTER 'State-Level Geographic Performance Summary' SKIP 1 -
       CENTER 'For Years &start_year_prompt to &end_year_prompt' SKIP 1 -
       CENTER '=====================================================' SKIP 1-
       LEFT 'Report Generated on: ' _DATE  -
       RIGHT 'Page: ' SQL.PNO SKIP 2

-- Define column formats
COLUMN member_state FORMAT A20 HEADING 'State'
COLUMN avg_sales_per_member FORMAT '999,999.99' HEADING 'Avg Sales (RM)|Per Member'
COLUMN pct_active_members FORMAT A15 HEADING '% of Active|Members'
COLUMN pct_total_revenue FORMAT A15 HEADING '% of Total|Revenue'

-- The query aggregates the city-level data from the view to the state level.
WITH
STATE_AGGREGATES AS (
    SELECT
        memberState as member_state,
        SUM(sales_in_geo) as sales_in_state,
        SUM(members_in_geo) as members_in_state
    FROM GEO_CITY_PERFORMANCE_V
    GROUP BY memberState
),
PERIOD_TOTALS AS (
    SELECT
        SUM(sales_in_geo) AS total_sales_in_period,
        SUM(members_in_geo) AS total_members_in_period
    FROM GEO_CITY_PERFORMANCE_V
)
SELECT
    sa.member_state,
    sa.sales_in_state / sa.members_in_state AS avg_sales_per_member,
    TO_CHAR(ROUND((sa.members_in_state * 100.0 / pt.total_members_in_period), 2), '990.99') || '%' AS pct_active_members,
    TO_CHAR(ROUND((sa.sales_in_state * 100.0 / pt.total_sales_in_period), 2), '990.99') || '%' AS pct_total_revenue
FROM
    STATE_AGGREGATES sa,
    PERIOD_TOTALS pt
WHERE
    sa.members_in_state > 0
ORDER BY
    avg_sales_per_member DESC;



-- Report 2: Interactive City-Level Drill-Down
PROMPT
PROMPT
ACCEPT drilldown_state_prompt CHAR PROMPT 'Enter State to see city-level detail (or press Enter to skip): '
ACCEPT top_n_prompt CHAR PROMPT 'Enter the number of Top Cities to display (e.g., 5): '
PROMPT

-- Define formats for the drill-down report
CLEAR COLUMNS
TTITLE CENTER '=====================================================' SKIP 1 -
       CENTER 'Top &top_n_prompt City-Level Detail for &drilldown_state_prompt' SKIP 1 -
       CENTER 'For Years &start_year_prompt to &end_year_prompt' SKIP 1 -
       CENTER '=====================================================' SKIP 2

COLUMN ranking FORMAT 999 HEADING 'Rnk'
COLUMN member_city FORMAT A20 HEADING 'City'
COLUMN members_in_geo FORMAT 999,999 HEADING 'Members'
COLUMN avg_sales_per_member FORMAT '999,999.99' HEADING 'Avg Sales'
COLUMN pct_active_members FORMAT A10 HEADING '% Members'
COLUMN pct_total_revenue FORMAT A10 HEADING '% Revenue'
COLUMN cumulative_pct_revenue FORMAT A10 HEADING 'Cumulative|% Rev'

-- This query runs ONLY if a state was entered. It now filters for the Top N cities.
WITH
STATE_TOTALS AS (
    SELECT
        SUM(sales_in_geo) as total_sales_in_state,
        SUM(members_in_geo) as total_members_in_state
    FROM GEO_CITY_PERFORMANCE_V
    WHERE UPPER(memberState) = UPPER('&drilldown_state_prompt')
),
RANKED_CITIES AS (
    SELECT
        RANK() OVER (ORDER BY (ca.sales_in_geo / ca.members_in_geo) DESC) as ranking,
        ca.memberCity as member_city,
        ca.members_in_geo,
        ca.sales_in_geo,
        ca.sales_in_geo / ca.members_in_geo AS avg_sales_per_member,
        (ca.members_in_geo * 100.0 / st.total_members_in_state) AS pct_active_members,
        (ca.sales_in_geo * 100.0 / st.total_sales_in_state) AS pct_total_revenue
    FROM
        GEO_CITY_PERFORMANCE_V ca,
        STATE_TOTALS st
    WHERE
        UPPER(ca.memberState) = UPPER('&drilldown_state_prompt')
        AND ca.members_in_geo > 0
),
CUMULATIVE_CITIES AS (
    SELECT
        rc.*,
        SUM(pct_total_revenue) OVER (ORDER BY ranking) as cumulative_pct_revenue
    FROM RANKED_CITIES rc
)
SELECT
    ranking,
    member_city,
    members_in_geo,
    avg_sales_per_member,
    TO_CHAR(ROUND(pct_active_members, 1), '990.9') || '%' AS pct_active_members,
    TO_CHAR(ROUND(pct_total_revenue, 1), '990.9') || '%' AS pct_total_revenue,
    TO_CHAR(ROUND(cumulative_pct_revenue, 1), '990.9') || '%' AS cumulative_pct_revenue
FROM CUMULATIVE_CITIES
WHERE ranking <= TO_NUMBER('&top_n_prompt')
ORDER BY
    ranking;



-- Cleanup
PROMPT
PROMPT Dropping temporary view...
DROP VIEW GEO_CITY_PERFORMANCE_V;

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES
UNDEFINE start_year_prompt
UNDEFINE end_year_prompt
UNDEFINE drilldown_state_prompt
UNDEFINE top_n_prompt
SET FEEDBACK ON
SET VERIFY ON
TTITLE OFF
PROMPT
PROMPT Report complete.
PROMPT

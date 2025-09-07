-- 3.1.1 Sales Trend & Seasonality Analysis by Book Category
-- Purpose: Identify seasonal sales patterns and profitability by category over the last 60 months
-- Notes/Assumptions:
-- - Environment: Oracle SQL*Plus (uses SET commands below)
-- - Fact table: sales_fact(sf) with columns: date_key, book_key, orderQty, orderUnitPrice, purchaseUnitPrice
-- - Date dimension: date_dim(dd) with columns: date_key, full_date, cal_month_name, cal_year
-- - Book dimension: book_dim(bd) with columns: book_key, bookCategory
-- - Profit = (orderUnitPrice - purchaseUnitPrice) * orderQty
-- - Last 60 months includes the current month and previous 59 months

SET LINESIZE 130
SET PAGESIZE 35
SET TAB OFF
SET TRIMSPOOL ON

COLUMN month_label       FORMAT A10 HEADING 'Month'
COLUMN category          FORMAT A30 HEADING 'Book Category'
COLUMN sales_qty         FORMAT 999,999,999 HEADING 'Sales Qty'
COLUMN gross_profit      FORMAT 999,999,999.99 HEADING 'Gross Profit'

PROMPT ===== 3.1.1 Sales Trend & Seasonality by Book Category (Last 60 Months) =====

WITH monthly AS (
  SELECT
    TRUNC(dd.full_date, 'MM')                                     AS month_start,
    dd.cal_year                                                    AS cal_year,
    dd.cal_month_name                                              AS cal_month_name,
    bd.bookCategory                                                AS category,
    SUM(sf.orderQty)                                               AS sales_qty,
    SUM((sf.orderUnitPrice - sf.purchaseUnitPrice) * sf.orderQty)  AS gross_profit
  FROM sales_fact sf
  JOIN date_dim dd
    ON dd.date_key = sf.date_key
  JOIN book_dim bd
    ON bd.book_key = sf.book_key
  WHERE dd.full_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -59)
  GROUP BY TRUNC(dd.full_date, 'MM'), dd.cal_year, dd.cal_month_name, bd.bookCategory
)
SELECT TO_CHAR(month_start, 'YYYY-MM') AS month_label,
       category,
       sales_qty,
       gross_profit
FROM monthly
ORDER BY month_start, category
;

PROMPT ===== Peak and Trough Months per Category (Based on Total Qty, Last 60 Months) =====

WITH base AS (
  SELECT
    dd.cal_month_name AS cal_month_name,
    bd.bookCategory   AS category,
    SUM(sf.orderQty)  AS total_qty
  FROM sales_fact sf
  JOIN date_dim dd
    ON dd.date_key = sf.date_key
  JOIN book_dim bd
    ON bd.book_key = sf.book_key
  WHERE dd.full_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -59)
  GROUP BY dd.cal_month_name, bd.bookCategory
),
ranked_max AS (
  SELECT
    category,
    cal_month_name,
    total_qty,
    RANK() OVER (PARTITION BY category ORDER BY total_qty DESC) AS rnk_desc
  FROM base
),
ranked_min AS (
  SELECT
    category,
    cal_month_name,
    total_qty,
    RANK() OVER (PARTITION BY category ORDER BY total_qty ASC) AS rnk_asc
  FROM base
)
SELECT m.category,
       m.cal_month_name AS peak_month,
       m.total_qty      AS peak_qty,
       n.cal_month_name AS trough_month,
       n.total_qty      AS trough_qty
FROM ranked_max m
JOIN ranked_min n
  ON n.category = m.category
WHERE m.rnk_desc = 1
  AND n.rnk_asc = 1
ORDER BY m.category
;

-- Visualization Tip:
-- - Use the first result set (month_label, category, sales_qty) to create a multi-series line chart
--   with month on the X-axis and one line per category. Optionally add gross_profit as a secondary measure.
-- Decision Guidance:
-- - Inventory Planning: Increase stock 4–6 weeks before each category's peak_month.
-- - Timed Promotions: Launch campaigns at the start of the upswing leading to peak_month.
-- - Dynamic Pricing: Consider modest price increases near peak_month and discounts near trough_month.


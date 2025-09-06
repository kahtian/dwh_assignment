-- =============================================
-- TRUNCATE ALL FACT TABLES FOR FULL RELOAD
-- =============================================
PROMPT Step 1: Truncating all fact tables...
TRUNCATE TABLE LOAN_FACT;
TRUNCATE TABLE SALES_FACT;
TRUNCATE TABLE PURCHASE_FACT;
TRUNCATE TABLE RESERVATION_FACT;

PROMPT All fact tables have been truncated and are ready for reloading.

PROMPT Step 2: Reloading corrected 10-year data...
PROMPT In your terminal, please run:
PROMPT python load_csv_to_oracle.py

PROMPT After running the Python script, please run the data validation again to confirm the fix.
PROMPT @DATA_VALIDATION.sql

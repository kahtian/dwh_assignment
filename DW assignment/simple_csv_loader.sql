-- =============================================
-- SIMPLE CSV LOADER - No External Tables Required
-- Purpose: Load CSV data using SQL*Plus with Python helper
-- =============================================

-- First disable the problematic foreign key constraints
ALTER TABLE SALES_FACT DISABLE CONSTRAINT SF_ORDERID_FK;
ALTER TABLE PURCHASE_FACT DISABLE CONSTRAINT PF_PURCHASEID_FK;  
ALTER TABLE LOAN_FACT DISABLE CONSTRAINT LF_LOANID_FK;
ALTER TABLE RESERVATION_FACT DISABLE CONSTRAINT RF_RESERVEID_FK;

PROMPT Foreign key constraints disabled for data loading...

-- Show current record counts (before loading)
PROMPT Current record counts (BEFORE CSV loading):
SELECT 'LOAN_FACT' as table_name, COUNT(*) as current_records FROM LOAN_FACT
UNION ALL SELECT 'SALES_FACT', COUNT(*) FROM SALES_FACT
UNION ALL SELECT 'PURCHASE_FACT', COUNT(*) FROM PURCHASE_FACT  
UNION ALL SELECT 'RESERVATION_FACT', COUNT(*) FROM RESERVATION_FACT;

PROMPT =============================================
PROMPT CSV files are ready for loading!
PROMPT =============================================
PROMPT Generated files:
PROMPT   - LOAN_FACT_data.csv (150K records)
PROMPT   - SALES_FACT_data.csv (120K records)  
PROMPT   - PURCHASE_FACT_data.csv (100K records)
PROMPT   - RESERVATION_FACT_data.csv (200K records)
PROMPT =============================================

PROMPT Next step: Use Python CSV loader (avoids Oracle External Table complexity)
PROMPT Run: python load_csv_to_oracle.py

-- Verify constraints are disabled
SELECT 
    table_name,
    constraint_name,
    status
FROM user_constraints 
WHERE constraint_name IN ('SF_ORDERID_FK', 'PF_PURCHASEID_FK', 'LF_LOANID_FK', 'RF_RESERVEID_FK');

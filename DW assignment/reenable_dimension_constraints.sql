-- =============================================
-- RE-ENABLE ESSENTIAL DIMENSION FOREIGN KEYS
-- =============================================
PROMPT Re-enabling foreign keys that reference DIMENSION tables...
PROMPT This is a best practice for maintaining the integrity of the star schema.

-- Re-enable Sales Fact dimension foreign keys
ALTER TABLE SALES_FACT ENABLE CONSTRAINT SF_DATE_FK;
ALTER TABLE SALES_FACT ENABLE CONSTRAINT SF_MEMBER_FK;
ALTER TABLE SALES_FACT ENABLE CONSTRAINT SF_BOOK_FK;
ALTER TABLE SALES_FACT ENABLE CONSTRAINT SF_STAFF_FK;

-- Re-enable Purchase Fact dimension foreign keys
ALTER TABLE PURCHASE_FACT ENABLE CONSTRAINT PF_DATE_FK;
ALTER TABLE PURCHASE_FACT ENABLE CONSTRAINT PF_BOOK_FK;
ALTER TABLE PURCHASE_FACT ENABLE CONSTRAINT PF_STAFF_FK;
ALTER TABLE PURCHASE_FACT ENABLE CONSTRAINT PF_SUPPLIER_FK;

-- Re-enable Loan Fact dimension foreign keys
ALTER TABLE LOAN_FACT ENABLE CONSTRAINT LF_MEMBER_FK;
ALTER TABLE LOAN_FACT ENABLE CONSTRAINT LF_BOOK_FK;
ALTER TABLE LOAN_FACT ENABLE CONSTRAINT LF_STAFF_FK;
ALTER TABLE LOAN_FACT ENABLE CONSTRAINT LF_DATE_FK;

-- Re-enable Reservation Fact dimension foreign keys
ALTER TABLE RESERVATION_FACT ENABLE CONSTRAINT RF_MEMBER_FK;
ALTER TABLE RESERVATION_FACT ENABLE CONSTRAINT RF_BOOK_FK;
ALTER TABLE RESERVATION_FACT ENABLE CONSTRAINT RF_STAFF_FK;
ALTER TABLE RESERVATION_FACT ENABLE CONSTRAINT RF_START_DATE_FK;
ALTER TABLE RESERVATION_FACT ENABLE CONSTRAINT RF_END_DATE_FK;

PROMPT All dimension foreign keys have been re-enabled.

PROMPT Verifying constraint status...
-- This query should now show all dimension FKs as 'ENABLED'
-- and all source table FKs as 'DISABLED'.
SELECT 
    table_name,
    constraint_name,
    status,
    CASE 
        WHEN constraint_name LIKE '%_FK' AND constraint_name NOT IN ('SF_ORDERID_FK', 'PF_PURCHASEID_FK', 'LF_LOANID_FK', 'RF_RESERVEID_FK')
        THEN 'Dimension FK - Should be ENABLED'
        WHEN constraint_name IN ('SF_ORDERID_FK', 'PF_PURCHASEID_FK', 'LF_LOANID_FK', 'RF_RESERVEID_FK')
        THEN 'Source Table FK - Should be DISABLED'
        ELSE 'Primary Key / Check Constraint'
    END as description
FROM user_constraints 
WHERE table_name IN ('SALES_FACT', 'PURCHASE_FACT', 'LOAN_FACT', 'RESERVATION_FACT')
ORDER BY table_name, constraint_name;

PROMPT =============================================
PROMPT CONSTRAINT MANAGEMENT COMPLETE
PROMPT Your data warehouse now has the optimal constraint setup.
PROMPT =============================================

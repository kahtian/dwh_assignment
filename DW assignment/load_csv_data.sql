-- =============================================
-- BULK LOAD CSV DATA INTO FACT TABLES
-- Purpose: Load generated CSV files using Oracle native tools
-- =============================================

-- Temporarily disable source table foreign keys
ALTER TABLE SALES_FACT DISABLE CONSTRAINT SF_ORDERID_FK;
ALTER TABLE PURCHASE_FACT DISABLE CONSTRAINT PF_PURCHASEID_FK;  
ALTER TABLE LOAN_FACT DISABLE CONSTRAINT LF_LOANID_FK;
ALTER TABLE RESERVATION_FACT DISABLE CONSTRAINT RF_RESERVEID_FK;

-- Set session for bulk operations
SET TIMING ON;
SET FEEDBACK ON;

-- =============================================
-- LOAD LOAN_FACT DATA
-- =============================================
PROMPT Loading LOAN_FACT data...

-- Create external table for LOAN_FACT
CREATE TABLE LOAN_FACT_EXT (
    member_key NUMBER,
    book_key NUMBER,
    staff_key NUMBER,
    date_key NUMBER,
    loanID VARCHAR2(6),
    loanDuration NUMBER,
    overdueDays NUMBER,
    loanStatus VARCHAR2(20),
    totalFine NUMBER(8,2),
    fine_paid_flag NUMBER(1)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY DATA_PUMP_DIR
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        (
            member_key,
            book_key,
            staff_key,
            date_key,
            loanID,
            loanDuration,
            overdueDays,
            loanStatus,
            totalFine,
            fine_paid_flag
        )
    )
    LOCATION ('LOAN_FACT_data.csv')
)
REJECT LIMIT UNLIMITED;

-- Insert from external table
INSERT INTO LOAN_FACT 
SELECT * FROM LOAN_FACT_EXT;

COMMIT;
PROMPT LOAN_FACT loading completed!

-- =============================================
-- LOAD SALES_FACT DATA  
-- =============================================
PROMPT Loading SALES_FACT data...

CREATE TABLE SALES_FACT_EXT (
    date_key NUMBER,
    member_key NUMBER,
    book_key NUMBER,
    staff_key NUMBER,
    orderID VARCHAR2(6),
    orderQty NUMBER,
    orderUnitPrice NUMBER(10,2),
    orderTotalPrice NUMBER(12,2)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY DATA_PUMP_DIR
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
    )
    LOCATION ('SALES_FACT_data.csv')
)
REJECT LIMIT UNLIMITED;

INSERT INTO SALES_FACT 
SELECT * FROM SALES_FACT_EXT;

COMMIT;
PROMPT SALES_FACT loading completed!

-- =============================================
-- LOAD PURCHASE_FACT DATA
-- =============================================
PROMPT Loading PURCHASE_FACT data...

CREATE TABLE PURCHASE_FACT_EXT (
    date_key NUMBER,
    book_key NUMBER,
    staff_key NUMBER,
    supplier_key NUMBER,
    purchaseID VARCHAR2(10),
    purchaseQuantity NUMBER,
    purchaseUnitCost NUMBER(10,2),
    purchaseTotalCost NUMBER(12,2)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY DATA_PUMP_DIR
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
    )
    LOCATION ('PURCHASE_FACT_data.csv')
)
REJECT LIMIT UNLIMITED;

INSERT INTO PURCHASE_FACT 
SELECT * FROM PURCHASE_FACT_EXT;

COMMIT;
PROMPT PURCHASE_FACT loading completed!

-- =============================================
-- LOAD RESERVATION_FACT DATA
-- =============================================
PROMPT Loading RESERVATION_FACT data...

CREATE TABLE RESERVATION_FACT_EXT (
    member_key NUMBER,
    book_key NUMBER,
    staff_key NUMBER,
    reserve_start_date_key NUMBER,
    reserve_end_date_key NUMBER,
    reserveID VARCHAR2(6),
    reservationStatus VARCHAR2(20),
    reservationDuration NUMBER
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY DATA_PUMP_DIR
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
    )
    LOCATION ('RESERVATION_FACT_data.csv')
)
REJECT LIMIT UNLIMITED;

INSERT INTO RESERVATION_FACT 
SELECT * FROM RESERVATION_FACT_EXT;

COMMIT;
PROMPT RESERVATION_FACT loading completed!

-- =============================================
-- CLEANUP AND VERIFICATION
-- =============================================
-- Drop external tables (optional)
DROP TABLE LOAN_FACT_EXT;
DROP TABLE SALES_FACT_EXT;
DROP TABLE PURCHASE_FACT_EXT;  
DROP TABLE RESERVATION_FACT_EXT;

-- Show final counts
PROMPT Final record counts:
SELECT 'LOAN_FACT' as table_name, COUNT(*) as records FROM LOAN_FACT
UNION ALL SELECT 'SALES_FACT', COUNT(*) FROM SALES_FACT
UNION ALL SELECT 'PURCHASE_FACT', COUNT(*) FROM PURCHASE_FACT  
UNION ALL SELECT 'RESERVATION_FACT', COUNT(*) FROM RESERVATION_FACT;

PROMPT =============================================
PROMPT CSV BULK LOADING COMPLETED!
PROMPT Run VOLUME_CHECK.sql to verify targets met
PROMPT =============================================

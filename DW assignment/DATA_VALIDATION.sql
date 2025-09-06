-- =============================================
-- DATA WAREHOUSE VALIDATION SCRIPT
-- Purpose: Verify data logic and 10-year coverage
-- =============================================

-- =============================================
-- 1. DATE DIMENSION COVERAGE VALIDATION
-- =============================================

-- Verify exact 10-year coverage (2016-2025)
SELECT 
    MIN(CAL_DATE) as start_date,
    MAX(CAL_DATE) as end_date,
    COUNT(*) as total_days,
    COUNT(DISTINCT CAL_YEAR) as years_covered
FROM DATE_DIM;

-- Expected Results:
-- start_date: 01-JAN-16
-- end_date: 30-DEC-25  
-- total_days: 3650
-- years_covered: 10

-- Verify no gaps in date sequence
SELECT COUNT(*) as missing_dates
FROM (
    SELECT CAL_DATE + 1 as next_expected_date
    FROM DATE_DIM
    WHERE CAL_DATE + 1 NOT IN (SELECT CAL_DATE FROM DATE_DIM)
      AND CAL_DATE < (SELECT MAX(CAL_DATE) FROM DATE_DIM)
);

-- Expected Result: missing_dates = 0

-- Verify special period indicators are set correctly
SELECT 
    CAL_YEAR,
    SUM(CASE WHEN STUDY_WEEK_IND = 'Y' THEN 1 ELSE 0 END) as study_days,
    SUM(CASE WHEN EXAM_WEEK_IND = 'Y' THEN 1 ELSE 0 END) as exam_days,
    SUM(CASE WHEN WEEKDAY_IND = 'Y' THEN 1 ELSE 0 END) as weekdays
FROM DATE_DIM 
GROUP BY CAL_YEAR 
ORDER BY CAL_YEAR;

-- =============================================
-- 2. DIMENSION DATA COMPLETENESS
-- =============================================

-- Count records in each dimension
SELECT 'BOOK_DIM' as table_name, COUNT(*) as record_count FROM BOOK_DIM
UNION ALL
SELECT 'MEMBER_DIM', COUNT(*) FROM MEMBER_DIM
UNION ALL
SELECT 'STAFF_DIM', COUNT(*) FROM STAFF_DIM
UNION ALL
SELECT 'SUPPLIER_DIM', COUNT(*) FROM SUPPLIER_DIM
UNION ALL
SELECT 'DATE_DIM', COUNT(*) FROM DATE_DIM;

-- Verify no NULL values in critical dimension keys
SELECT 
    'BOOK_DIM' as table_name,
    COUNT(*) as total_records,
    COUNT(book_key) as non_null_keys,
    COUNT(bookID) as non_null_business_keys
FROM BOOK_DIM
UNION ALL
SELECT 
    'MEMBER_DIM',
    COUNT(*) as total_records,
    COUNT(member_key) as non_null_keys,
    COUNT(memberID) as non_null_business_keys
FROM MEMBER_DIM
UNION ALL
SELECT 
    'STAFF_DIM',
    COUNT(*) as total_records,
    COUNT(staff_key) as non_null_keys,
    COUNT(staffID) as non_null_business_keys
FROM STAFF_DIM
UNION ALL
SELECT 
    'SUPPLIER_DIM',
    COUNT(*) as total_records,
    COUNT(supplier_key) as non_null_keys,
    COUNT(supplierID) as non_null_business_keys
FROM SUPPLIER_DIM;

-- =============================================
-- 3. FACT TABLE DATA DISTRIBUTION
-- =============================================

-- Verify fact tables have data across the full date range
SELECT 
    'PURCHASE_FACT' as fact_table,
    COUNT(*) as total_records,
    MIN(D.CAL_DATE) as earliest_transaction,
    MAX(D.CAL_DATE) as latest_transaction,
    COUNT(DISTINCT D.CAL_YEAR) as years_with_data
FROM PURCHASE_FACT PF
JOIN DATE_DIM D ON PF.date_key = D.date_key
UNION ALL
SELECT 
    'SALES_FACT',
    COUNT(*) as total_records,
    MIN(D.CAL_DATE) as earliest_transaction,
    MAX(D.CAL_DATE) as latest_transaction,
    COUNT(DISTINCT D.CAL_YEAR) as years_with_data
FROM SALES_FACT SF
JOIN DATE_DIM D ON SF.date_key = D.date_key
UNION ALL
SELECT 
    'LOAN_FACT',
    COUNT(*) as total_records,
    MIN(D.CAL_DATE) as earliest_transaction,
    MAX(D.CAL_DATE) as latest_transaction,
    COUNT(DISTINCT D.CAL_YEAR) as years_with_data
FROM LOAN_FACT LF
JOIN DATE_DIM D ON LF.date_key = D.date_key
UNION ALL
SELECT 
    'RESERVATION_FACT',
    COUNT(*) as total_records,
    MIN(D.CAL_DATE) as earliest_transaction,
    MAX(D.CAL_DATE) as latest_transaction,
    COUNT(DISTINCT D.CAL_YEAR) as years_with_data
FROM RESERVATION_FACT RF
JOIN DATE_DIM D ON RF.reserve_start_date_key = D.date_key;

-- =============================================
-- 4. REFERENTIAL INTEGRITY VALIDATION
-- =============================================

-- Check for orphaned records in fact tables (should return 0 for all)
SELECT 'PURCHASE_FACT orphaned date_keys' as check_name,
       COUNT(*) as orphaned_count
FROM PURCHASE_FACT PF
LEFT JOIN DATE_DIM D ON PF.date_key = D.date_key
WHERE D.date_key IS NULL
UNION ALL
SELECT 'PURCHASE_FACT orphaned book_keys',
       COUNT(*)
FROM PURCHASE_FACT PF
LEFT JOIN BOOK_DIM B ON PF.book_key = B.book_key
WHERE B.book_key IS NULL
UNION ALL
SELECT 'SALES_FACT orphaned member_keys',
       COUNT(*)
FROM SALES_FACT SF
LEFT JOIN MEMBER_DIM M ON SF.member_key = M.member_key
WHERE M.member_key IS NULL
UNION ALL
SELECT 'LOAN_FACT orphaned staff_keys',
       COUNT(*)
FROM LOAN_FACT LF
LEFT JOIN STAFF_DIM S ON LF.staff_key = S.staff_key
WHERE S.staff_key IS NULL
UNION ALL
SELECT 'RESERVATION_FACT orphaned start_date_keys',
       COUNT(*)
FROM RESERVATION_FACT RF
LEFT JOIN DATE_DIM D ON RF.reserve_start_date_key = D.date_key
WHERE D.date_key IS NULL
UNION ALL
SELECT 'RESERVATION_FACT orphaned end_date_keys',
       COUNT(*)
FROM RESERVATION_FACT RF
LEFT JOIN DATE_DIM D ON RF.reserve_end_date_key = D.date_key
WHERE D.date_key IS NULL;

-- =============================================
-- 5. BUSINESS LOGIC VALIDATION
-- =============================================

-- Verify reservation expiry logic (7-day default)
SELECT 
    reservationDuration,
    COUNT(*) as reservation_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM RESERVATION_FACT 
WHERE reservationDuration IS NOT NULL
GROUP BY reservationDuration
ORDER BY reservationDuration;

-- Verify calculated fields in facts
SELECT 
    'PURCHASE_FACT calculated totals' as validation,
    COUNT(*) as records_checked,
    SUM(CASE WHEN ABS(purchaseTotalCost - (purchaseQuantity * purchaseUnitCost)) > 0.01 
             THEN 1 ELSE 0 END) as calculation_errors
FROM PURCHASE_FACT
UNION ALL
SELECT 
    'SALES_FACT calculated totals',
    COUNT(*) as records_checked,
    SUM(CASE WHEN ABS(orderTotalPrice - (orderQty * orderUnitPrice)) > 0.01 
             THEN 1 ELSE 0 END) as calculation_errors
FROM SALES_FACT;

-- Verify loan overdue calculations make sense
SELECT 
    'Positive overdue days' as check_name,
    COUNT(*) as count
FROM LOAN_FACT 
WHERE overdueDays > 0
UNION ALL
SELECT 
    'Zero overdue days (on-time returns)',
    COUNT(*)
FROM LOAN_FACT 
WHERE overdueDays = 0
UNION ALL
SELECT 
    'Negative overdue days (early returns)',
    COUNT(*)
FROM LOAN_FACT 
WHERE overdueDays < 0;

-- =============================================
-- 6. DATA QUALITY CHECKS
-- =============================================

-- Check for reasonable date ranges in calculated durations
SELECT 
    MIN(reservationDuration) as min_duration,
    MAX(reservationDuration) as max_duration,
    AVG(reservationDuration) as avg_duration,
    COUNT(CASE WHEN reservationDuration < 0 THEN 1 END) as negative_durations,
    COUNT(CASE WHEN reservationDuration > 365 THEN 1 END) as unrealistic_durations
FROM RESERVATION_FACT;

-- Check for reasonable values in financial fields
SELECT 
    'PURCHASE_FACT' as table_name,
    MIN(purchaseUnitCost) as min_unit_cost,
    MAX(purchaseUnitCost) as max_unit_cost,
    AVG(purchaseUnitCost) as avg_unit_cost,
    COUNT(CASE WHEN purchaseUnitCost <= 0 THEN 1 END) as non_positive_costs
FROM PURCHASE_FACT
UNION ALL
SELECT 
    'SALES_FACT',
    MIN(orderUnitPrice),
    MAX(orderUnitPrice),
    AVG(orderUnitPrice),
    COUNT(CASE WHEN orderUnitPrice <= 0 THEN 1 END)
FROM SALES_FACT;

-- =============================================
-- 7. CROSS-FACT CONSISTENCY CHECKS
-- =============================================

-- Verify same books exist across different fact tables
SELECT 
    B.bookTitle,
    COUNT(DISTINCT PF.book_key) as in_purchases,
    COUNT(DISTINCT SF.book_key) as in_sales,
    COUNT(DISTINCT LF.book_key) as in_loans
FROM BOOK_DIM B
LEFT JOIN PURCHASE_FACT PF ON B.book_key = PF.book_key
LEFT JOIN SALES_FACT SF ON B.book_key = SF.book_key  
LEFT JOIN LOAN_FACT LF ON B.book_key = LF.book_key
GROUP BY B.bookTitle
HAVING COUNT(DISTINCT PF.book_key) > 0 
    OR COUNT(DISTINCT SF.book_key) > 0 
    OR COUNT(DISTINCT LF.book_key) > 0
ORDER BY B.bookTitle;

-- Verify staff activity across different processes
SELECT 
    S.staffName,
    COUNT(DISTINCT PF.staff_key) as purchases_processed,
    COUNT(DISTINCT SF.staff_key) as sales_processed,
    COUNT(DISTINCT LF.staff_key) as loans_processed
FROM STAFF_DIM S
LEFT JOIN PURCHASE_FACT PF ON S.staff_key = PF.staff_key
LEFT JOIN SALES_FACT SF ON S.staff_key = SF.staff_key
LEFT JOIN LOAN_FACT LF ON S.staff_key = LF.staff_key
WHERE S.is_current_flag = '1'
GROUP BY S.staffName
ORDER BY S.staffName;

-- =============================================
-- 8. SUMMARY VALIDATION REPORT
-- =============================================

-- Final summary of data warehouse health
SELECT 
    'Date Range Coverage' as metric,
    CASE WHEN COUNT(DISTINCT CAL_YEAR) = 10 THEN 'PASS' ELSE 'FAIL' END as status,
    COUNT(DISTINCT CAL_YEAR) || ' years covered' as details
FROM DATE_DIM
UNION ALL
SELECT 
    'Total Fact Records',
    CASE WHEN (SELECT COUNT(*) FROM PURCHASE_FACT) + 
              (SELECT COUNT(*) FROM SALES_FACT) + 
              (SELECT COUNT(*) FROM LOAN_FACT) + 
              (SELECT COUNT(*) FROM RESERVATION_FACT) > 0 
         THEN 'PASS' ELSE 'FAIL' END,
    TO_CHAR((SELECT COUNT(*) FROM PURCHASE_FACT) + 
            (SELECT COUNT(*) FROM SALES_FACT) + 
            (SELECT COUNT(*) FROM LOAN_FACT) + 
            (SELECT COUNT(*) FROM RESERVATION_FACT)) || ' total transactions'
FROM DUAL
UNION ALL
SELECT 
    'Dimension Completeness',
    CASE WHEN (SELECT COUNT(*) FROM BOOK_DIM) > 0 AND
              (SELECT COUNT(*) FROM MEMBER_DIM) > 0 AND  
              (SELECT COUNT(*) FROM STAFF_DIM) > 0 AND
              (SELECT COUNT(*) FROM SUPPLIER_DIM) > 0
         THEN 'PASS' ELSE 'FAIL' END,
    'All dimensions populated'
FROM DUAL;

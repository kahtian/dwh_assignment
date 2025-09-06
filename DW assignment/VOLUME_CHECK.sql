-- =============================================
-- VOLUME VERIFICATION - Check 100K+ Records Per Fact Table
-- Run this after GENERATE_ALL_FACT_DATA to verify targets met
-- =============================================

SELECT 
    'LOAN_FACT' as fact_table,
    COUNT(*) as record_count,
    CASE WHEN COUNT(*) >= 100000 THEN '✅ TARGET MET' ELSE '❌ BELOW TARGET' END as status,
    '150K Target' as target
FROM LOAN_FACT

UNION ALL

SELECT 
    'SALES_FACT',
    COUNT(*),
    CASE WHEN COUNT(*) >= 100000 THEN '✅ TARGET MET' ELSE '❌ BELOW TARGET' END,
    '120K Target'
FROM SALES_FACT

UNION ALL

SELECT 
    'PURCHASE_FACT',
    COUNT(*),
    CASE WHEN COUNT(*) >= 100000 THEN '✅ TARGET MET' ELSE '❌ BELOW TARGET' END,
    '100K Target'
FROM PURCHASE_FACT

UNION ALL

SELECT 
    'RESERVATION_FACT',
    COUNT(*),
    CASE WHEN COUNT(*) >= 100000 THEN '✅ TARGET MET' ELSE '❌ BELOW TARGET' END,
    '200K Target'
FROM RESERVATION_FACT

UNION ALL

SELECT 
    '*** TOTAL ***',
    (SELECT COUNT(*) FROM LOAN_FACT) + 
    (SELECT COUNT(*) FROM SALES_FACT) + 
    (SELECT COUNT(*) FROM PURCHASE_FACT) + 
    (SELECT COUNT(*) FROM RESERVATION_FACT),
    CASE WHEN (
        (SELECT COUNT(*) FROM LOAN_FACT) + 
        (SELECT COUNT(*) FROM SALES_FACT) + 
        (SELECT COUNT(*) FROM PURCHASE_FACT) + 
        (SELECT COUNT(*) FROM RESERVATION_FACT)
    ) >= 570000 THEN '🎯 ALL TARGETS MET!' ELSE '⚠️ REVIEW NEEDED' END,
    '570K+ Total'
FROM DUAL

ORDER BY 
    CASE fact_table 
        WHEN 'LOAN_FACT' THEN 1
        WHEN 'SALES_FACT' THEN 2
        WHEN 'PURCHASE_FACT' THEN 3
        WHEN 'RESERVATION_FACT' THEN 4
        ELSE 5
    END;

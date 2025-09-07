-- ===================================================================================
-- Seasonal Book Damage Simulation
-- Purpose: Simulate realistic wear and tear patterns based on seasonal usage
-- This procedure updates BOOK_DIM.bookCondition to reflect the impact of heavy
-- usage during high-stress academic periods (Exam Week and Study Week).
-- ===================================================================================

-- ===================================================================================
-- Main Simulation Procedure
-- ===================================================================================
CREATE OR REPLACE PROCEDURE SIMULATE_SEASONAL_DAMAGE AS
    v_good_to_fair NUMBER := 0;
    v_fair_to_poor NUMBER := 0;
    v_total_updated NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting seasonal damage simulation...');
    DBMS_OUTPUT.PUT_LINE('==========================================');
    
    -- =============================================================================
    -- Phase 1: GOOD → FAIR (Books with moderate high-stress usage)
    -- =============================================================================
    DBMS_OUTPUT.PUT_LINE('Phase 1: Downgrading GOOD books to FAIR...');
    
    -- Update books that were borrowed 3+ times during Exam Weeks
    UPDATE BOOK_DIM bd
    SET bookCondition = 'FAIR'
    WHERE bd.book_key IN (
        SELECT lf.book_key 
        FROM LOAN_FACT lf 
        JOIN DATE_DIM dd ON lf.date_key = dd.date_key
        WHERE dd.EXAM_WEEK_IND = 'Y'
        GROUP BY lf.book_key 
        HAVING COUNT(*) >= 3
    )
    AND bd.bookCondition = 'GOOD'
    AND DBMS_RANDOM.VALUE < 0.6; -- 60% chance for realism
    
    v_good_to_fair := v_good_to_fair + SQL%ROWCOUNT;
    
    -- Update books that were borrowed 4+ times during Study Weeks
    UPDATE BOOK_DIM bd
    SET bookCondition = 'FAIR'
    WHERE bd.book_key IN (
        SELECT lf.book_key 
        FROM LOAN_FACT lf 
        JOIN DATE_DIM dd ON lf.date_key = dd.date_key
        WHERE dd.STUDY_WEEK_IND = 'Y'
        GROUP BY lf.book_key 
        HAVING COUNT(*) >= 4
    )
    AND bd.bookCondition = 'GOOD'
    AND DBMS_RANDOM.VALUE < 0.5; -- 50% chance (Study Week slightly less damaging)
    
    v_good_to_fair := v_good_to_fair + SQL%ROWCOUNT;
    
    -- Category-specific degradation: Technical books are more fragile during Exam Week
    UPDATE BOOK_DIM bd
    SET bookCondition = 'FAIR'
    WHERE bd.book_key IN (
        SELECT lf.book_key 
        FROM LOAN_FACT lf 
        JOIN DATE_DIM dd ON lf.date_key = dd.date_key
        WHERE dd.EXAM_WEEK_IND = 'Y'
        GROUP BY lf.book_key 
        HAVING COUNT(*) >= 2 -- Lower threshold for technical books
    )
    AND bd.bookCondition = 'GOOD'
    AND bd.bookCategory IN ('SCIENCE', 'NON-FICTION', 'EDUCATION', 'TECHNOLOGY')
    AND DBMS_RANDOM.VALUE < 0.7; -- 70% chance for technical books
    
    -- General degradation: All other categories with moderate usage
    UPDATE BOOK_DIM bd
    SET bookCondition = 'FAIR'
    WHERE bd.book_key IN (
        SELECT lf.book_key 
        FROM LOAN_FACT lf 
        JOIN DATE_DIM dd ON lf.date_key = dd.date_key
        WHERE dd.EXAM_WEEK_IND = 'Y' OR dd.STUDY_WEEK_IND = 'Y'
        GROUP BY lf.book_key 
        HAVING COUNT(*) >= 4 -- Higher threshold for other categories
    )
    AND bd.bookCondition = 'GOOD'
    AND bd.bookCategory NOT IN ('SCIENCE', 'NON-FICTION', 'EDUCATION', 'TECHNOLOGY')
    AND DBMS_RANDOM.VALUE < 0.4; -- 40% chance for non-technical books
    
    v_good_to_fair := v_good_to_fair + SQL%ROWCOUNT;
    
    DBMS_OUTPUT.PUT_LINE('  Books downgraded from GOOD to FAIR: ' || v_good_to_fair);
    
    -- =============================================================================
    -- Phase 2: FAIR → POOR (Books with heavy high-stress usage)
    -- =============================================================================
    DBMS_OUTPUT.PUT_LINE('Phase 2: Downgrading FAIR books to POOR...');
    
    -- Update books that were borrowed 5+ times during Exam Weeks
    UPDATE BOOK_DIM bd
    SET bookCondition = 'POOR'
    WHERE bd.book_key IN (
        SELECT lf.book_key 
        FROM LOAN_FACT lf 
        JOIN DATE_DIM dd ON lf.date_key = dd.date_key
        WHERE dd.EXAM_WEEK_IND = 'Y'
        GROUP BY lf.book_key 
        HAVING COUNT(*) >= 5
    )
    AND bd.bookCondition = 'FAIR'
    AND DBMS_RANDOM.VALUE < 0.7; -- 40% chance
    
    v_fair_to_poor := v_fair_to_poor + SQL%ROWCOUNT;
    
    -- Update books that were borrowed 6+ times during Study Weeks
    UPDATE BOOK_DIM bd
    SET bookCondition = 'POOR'
    WHERE bd.book_key IN (
        SELECT lf.book_key 
        FROM LOAN_FACT lf 
        JOIN DATE_DIM dd ON lf.date_key = dd.date_key
        WHERE dd.STUDY_WEEK_IND = 'Y'
        GROUP BY lf.book_key 
        HAVING COUNT(*) >= 6
    )
    AND bd.bookCondition = 'FAIR'
    AND DBMS_RANDOM.VALUE < 0.8; -- 30% chance
    
    v_fair_to_poor := v_fair_to_poor + SQL%ROWCOUNT;
    
    -- Books borrowed heavily during BOTH Exam and Study weeks (worst case)
    UPDATE BOOK_DIM bd
    SET bookCondition = 'POOR'
    WHERE bd.book_key IN (
        SELECT exam_books.book_key
        FROM (
            SELECT lf.book_key 
            FROM LOAN_FACT lf 
            JOIN DATE_DIM dd ON lf.date_key = dd.date_key
            WHERE dd.EXAM_WEEK_IND = 'Y'
            GROUP BY lf.book_key 
            HAVING COUNT(*) >= 2
        ) exam_books
        INNER JOIN (
            SELECT lf.book_key 
            FROM LOAN_FACT lf 
            JOIN DATE_DIM dd ON lf.date_key = dd.date_key
            WHERE dd.STUDY_WEEK_IND = 'Y'
            GROUP BY lf.book_key 
            HAVING COUNT(*) >= 2
        ) study_books ON exam_books.book_key = study_books.book_key
    )
    AND bd.bookCondition = 'FAIR'
    AND DBMS_RANDOM.VALUE < 0.8; -- 80% chance for books used in both periods
    
    v_fair_to_poor := v_fair_to_poor + SQL%ROWCOUNT;
    
    DBMS_OUTPUT.PUT_LINE('  Books downgraded from FAIR to POOR: ' || v_fair_to_poor);
    
    -- =============================================================================
    -- Final Summary
    -- =============================================================================
    v_total_updated := v_good_to_fair + v_fair_to_poor;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('Seasonal damage simulation completed!');
    DBMS_OUTPUT.PUT_LINE('Total books affected: ' || v_total_updated);
    DBMS_OUTPUT.PUT_LINE('  GOOD → FAIR: ' || v_good_to_fair);
    DBMS_OUTPUT.PUT_LINE('  FAIR → POOR: ' || v_fair_to_poor);
    DBMS_OUTPUT.PUT_LINE('==========================================');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR in seasonal damage simulation: ' || SQLERRM);
        RAISE;
END;
/

-- ===================================================================================
-- Utility Procedure: Reset All Books to GOOD (for testing)
-- ===================================================================================
CREATE OR REPLACE PROCEDURE RESET_BOOK_CONDITIONS AS
    v_count NUMBER;
BEGIN
    UPDATE BOOK_DIM SET bookCondition = 'GOOD';
    v_count := SQL%ROWCOUNT;
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('All ' || v_count || ' books reset to GOOD condition.');
END;
/

-- ===================================================================================
-- Analysis Procedure: Show Before/After Statistics
-- ===================================================================================
CREATE OR REPLACE PROCEDURE ANALYZE_BOOK_CONDITIONS AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('Current Book Condition Distribution:');
    DBMS_OUTPUT.PUT_LINE('=====================================');
    
    FOR rec IN (
        SELECT 
            bookCondition,
            COUNT(*) as book_count,
            ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
        FROM BOOK_DIM 
        GROUP BY bookCondition 
        ORDER BY 
            CASE bookCondition 
                WHEN 'GOOD' THEN 1 
                WHEN 'FAIR' THEN 2 
                WHEN 'POOR' THEN 3 
                ELSE 4 
            END
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.bookCondition, 10) || ': ' || 
            LPAD(TO_CHAR(rec.book_count, '999,999'), 8) || 
            ' (' || LPAD(TO_CHAR(rec.percentage, '990.99'), 6) || '%)'
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('=====================================');
END;
/

-- ===================================================================================
-- Usage Instructions
-- ===================================================================================
/*
USAGE INSTRUCTIONS:

1. To see current book condition distribution:
   EXEC ANALYZE_BOOK_CONDITIONS;

2. To run the seasonal damage simulation:
   EXEC SIMULATE_SEASONAL_DAMAGE;

3. To see the results:
   EXEC ANALYZE_BOOK_CONDITIONS;

4. To reset all books to GOOD condition (for testing):
   EXEC RESET_BOOK_CONDITIONS;

5. To run your q3_book_condition.sql report and see the realistic patterns:
   @q3_book_condition.sql

EXPECTED IMPACT:
- Books heavily used during Exam/Study weeks will show higher damage rates
- Science/Non-Fiction books will degrade faster during Exam weeks
- Your q3 report should now show meaningful seasonal patterns
- Damage percentages should be more realistic (10-25% instead of 65%+)
*/

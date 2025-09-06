-- =============================================
-- DATA GENERATION FOR 100K+ RECORDS PER FACT TABLE
-- Purpose: Academic calendar-driven realistic data multiplication
-- Strategy: Template-based duplication with seasonal patterns
-- =============================================

-- =============================================
-- LOAN_FACT GENERATION: 77K → 150K records
-- Academic patterns: Study weeks, renewals, course reserves
-- =============================================

CREATE OR REPLACE PROCEDURE GENERATE_LOAN_FACT_DATA AS
    v_count NUMBER := 0;
    v_base_count NUMBER;
    v_target_count NUMBER := 150000;
    
    CURSOR loan_templates IS
        SELECT lf.*, d.cal_date, d.study_week_ind, d.exam_week_ind, d.cal_month, d.cal_year
        FROM LOAN_FACT lf
        JOIN DATE_DIM d ON lf.date_key = d.date_key
        ORDER BY DBMS_RANDOM.VALUE;
BEGIN
    -- Get current count
    SELECT COUNT(*) INTO v_base_count FROM LOAN_FACT;
    DBMS_OUTPUT.PUT_LINE('Starting LOAN_FACT generation. Current records: ' || v_base_count);
    
    FOR template IN loan_templates LOOP
        EXIT WHEN v_count >= (v_target_count - v_base_count);
        
        -- Academic calendar multipliers
        DECLARE
            v_multiplier NUMBER;
            v_days_offset NUMBER;
            v_new_date DATE;
            v_new_date_key NUMBER;
            v_variations NUMBER;
        BEGIN
            -- Determine multiplier based on academic calendar
            IF template.study_week_ind = 'Y' THEN
                v_multiplier := 4; -- 4x during study weeks
            ELSIF template.exam_week_ind = 'Y' THEN
                v_multiplier := 5; -- 5x during exam weeks
            ELSIF template.cal_month IN (1, 9) THEN
                v_multiplier := 3; -- 3x semester starts
            ELSIF template.cal_month IN (6, 7, 12) THEN
                v_multiplier := 1; -- Normal during breaks
            ELSE
                v_multiplier := 2; -- 2x normal periods
            END IF;
            
            -- Generate variations for this template
            FOR i IN 1..LEAST(v_multiplier, 8) LOOP -- Cap at 8 variations per template
                -- Create time variations (spread across nearby dates)
                v_days_offset := ROUND(DBMS_RANDOM.VALUE(-30, 30));
                v_new_date := template.cal_date + v_days_offset;
                
                -- Get new date key
                BEGIN
                    SELECT date_key INTO v_new_date_key 
                    FROM DATE_DIM WHERE cal_date = v_new_date;
                    
                    -- Insert loan variation
                    INSERT INTO LOAN_FACT (
                        member_key, book_key, staff_key, date_key, loanID,
                        loanDuration, overdueDays, loanStatus, totalFine, fine_paid_flag
                    ) VALUES (
                        template.member_key,
                        template.book_key,
                        template.staff_key,
                        v_new_date_key,
                        'LG' || LPAD(LOAN_FACT_SEQ.NEXTVAL, 8, '0'), -- Generate new loanID
                        template.loanDuration + ROUND(DBMS_RANDOM.VALUE(-5, 5)), -- Vary duration
                        GREATEST(0, template.overdueDays + ROUND(DBMS_RANDOM.VALUE(-2, 3))), -- Vary overdue
                        template.loanStatus,
                        template.totalFine * DBMS_RANDOM.VALUE(0.5, 1.5), -- Vary fines
                        template.fine_paid_flag
                    );
                    
                    v_count := v_count + 1;
                    
                    -- Progress tracking
                    IF MOD(v_count, 10000) = 0 THEN
                        DBMS_OUTPUT.PUT_LINE('Generated ' || v_count || ' loan records...');
                        COMMIT;
                    END IF;
                    
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- Skip if date not in DATE_DIM
                        NULL;
                    WHEN DUP_VAL_ON_INDEX THEN
                        -- Skip if duplicate key
                        NULL;
                END;
                
                EXIT WHEN v_count >= (v_target_count - v_base_count);
            END LOOP;
        END;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('LOAN_FACT generation completed. Generated: ' || v_count || ' new records.');
    DBMS_OUTPUT.PUT_LINE('Total LOAN_FACT records: ' || (v_base_count + v_count));
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error in LOAN_FACT generation: ' || SQLERRM);
        RAISE;
END;
/

-- =============================================
-- SALES_FACT GENERATION: 39K → 120K records
-- Patterns: Textbook rush, semester sales, bulk orders
-- =============================================

CREATE OR REPLACE PROCEDURE GENERATE_SALES_FACT_DATA AS
    v_count NUMBER := 0;
    v_base_count NUMBER;
    v_target_count NUMBER := 120000;
    
    CURSOR sales_templates IS
        SELECT sf.*, d.cal_date, d.study_week_ind, d.exam_week_ind, d.cal_month, d.cal_year
        FROM SALES_FACT sf
        JOIN DATE_DIM d ON sf.date_key = d.date_key
        ORDER BY DBMS_RANDOM.VALUE;
BEGIN
    SELECT COUNT(*) INTO v_base_count FROM SALES_FACT;
    DBMS_OUTPUT.PUT_LINE('Starting SALES_FACT generation. Current records: ' || v_base_count);
    
    FOR template IN sales_templates LOOP
        EXIT WHEN v_count >= (v_target_count - v_base_count);
        
        DECLARE
            v_multiplier NUMBER;
            v_qty_boost NUMBER := 1;
            v_new_date DATE;
            v_new_date_key NUMBER;
        BEGIN
            -- Academic calendar multipliers
            IF template.cal_month IN (1, 8, 9) THEN
                v_multiplier := 6; -- Textbook rush periods
                v_qty_boost := 3; -- Multiple copies
            ELSIF template.study_week_ind = 'Y' OR template.exam_week_ind = 'Y' THEN
                v_multiplier := 4; -- Study guide sales
                v_qty_boost := 2;
            ELSIF template.cal_month IN (5, 12) THEN
                v_multiplier := 3; -- End of semester sales
            ELSE
                v_multiplier := 2; -- Regular periods
            END IF;
            
            -- Generate variations
            FOR i IN 1..LEAST(v_multiplier, 6) LOOP
                -- Time variations
                DECLARE
                    v_days_offset NUMBER := ROUND(DBMS_RANDOM.VALUE(-45, 45));
                BEGIN
                    v_new_date := template.cal_date + v_days_offset;
                    
                    SELECT date_key INTO v_new_date_key 
                    FROM DATE_DIM WHERE cal_date = v_new_date;
                    
                    -- Insert sales variation
                    INSERT INTO SALES_FACT (
                        date_key, member_key, book_key, staff_key, orderID,
                        orderQty, orderUnitPrice, orderTotalPrice
                    ) VALUES (
                        v_new_date_key,
                        template.member_key,
                        template.book_key,
                        template.staff_key,
                        'SG' || LPAD(SALES_FACT_SEQ.NEXTVAL, 8, '0'),
                        template.orderQty * v_qty_boost * ROUND(DBMS_RANDOM.VALUE(1, 3)), -- Bulk orders
                        template.orderUnitPrice * DBMS_RANDOM.VALUE(0.8, 1.2), -- Price variations
                        template.orderTotalPrice * v_qty_boost * DBMS_RANDOM.VALUE(1, 3)
                    );
                    
                    v_count := v_count + 1;
                    
                    IF MOD(v_count, 10000) = 0 THEN
                        DBMS_OUTPUT.PUT_LINE('Generated ' || v_count || ' sales records...');
                        COMMIT;
                    END IF;
                    
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;
                    WHEN DUP_VAL_ON_INDEX THEN NULL;
                END;
                
                EXIT WHEN v_count >= (v_target_count - v_base_count);
            END LOOP;
        END;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SALES_FACT generation completed. Generated: ' || v_count || ' new records.');
    DBMS_OUTPUT.PUT_LINE('Total SALES_FACT records: ' || (v_base_count + v_count));
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error in SALES_FACT generation: ' || SQLERRM);
        RAISE;
END;
/

-- =============================================
-- PURCHASE_FACT GENERATION: 12K → 100K records
-- Patterns: Semester prep, emergency orders, subscriptions
-- =============================================

CREATE OR REPLACE PROCEDURE GENERATE_PURCHASE_FACT_DATA AS
    v_count NUMBER := 0;
    v_base_count NUMBER;
    v_target_count NUMBER := 100000;
    
    CURSOR purchase_templates IS
        SELECT pf.*, d.cal_date, d.study_week_ind, d.exam_week_ind, d.cal_month
        FROM PURCHASE_FACT pf
        JOIN DATE_DIM d ON pf.date_key = d.date_key
        ORDER BY DBMS_RANDOM.VALUE;
BEGIN
    SELECT COUNT(*) INTO v_base_count FROM PURCHASE_FACT;
    DBMS_OUTPUT.PUT_LINE('Starting PURCHASE_FACT generation. Current records: ' || v_base_count);
    
    FOR template IN purchase_templates LOOP
        EXIT WHEN v_count >= (v_target_count - v_base_count);
        
        DECLARE
            v_multiplier NUMBER;
            v_new_date DATE;
            v_new_date_key NUMBER;
        BEGIN
            -- Semester preparation multipliers
            IF template.cal_month IN (8, 12) THEN
                v_multiplier := 12; -- Semester prep orders
            ELSIF template.cal_month IN (1, 6, 9) THEN
                v_multiplier := 8; -- Start of periods
            ELSIF template.study_week_ind = 'Y' THEN
                v_multiplier := 6; -- Emergency restocking
            ELSE
                v_multiplier := 4; -- Regular restocking
            END IF;
            
            -- Generate purchase variations (break large orders into smaller ones)
            FOR i IN 1..v_multiplier LOOP
                -- Spread orders across time
                DECLARE
                    v_days_offset NUMBER := ROUND(DBMS_RANDOM.VALUE(-60, 60));
                BEGIN
                    v_new_date := template.cal_date + v_days_offset;
                    
                    SELECT date_key INTO v_new_date_key 
                    FROM DATE_DIM WHERE cal_date = v_new_date;
                    
                    -- Insert purchase variation
                    INSERT INTO PURCHASE_FACT (
                        date_key, book_key, staff_key, supplier_key, purchaseID,
                        purchaseQuantity, purchaseUnitCost, purchaseTotalCost
                    ) VALUES (
                        v_new_date_key,
                        template.book_key,
                        template.staff_key,
                        template.supplier_key,
                        'PG' || LPAD(PURCHASE_FACT_SEQ.NEXTVAL, 8, '0'),
                        ROUND(template.purchaseQuantity * DBMS_RANDOM.VALUE(0.3, 2.0)), -- Vary quantities
                        template.purchaseUnitCost * DBMS_RANDOM.VALUE(0.9, 1.1), -- Slight price variation
                        template.purchaseTotalCost * DBMS_RANDOM.VALUE(0.5, 1.8) -- Vary totals
                    );
                    
                    v_count := v_count + 1;
                    
                    IF MOD(v_count, 10000) = 0 THEN
                        DBMS_OUTPUT.PUT_LINE('Generated ' || v_count || ' purchase records...');
                        COMMIT;
                    END IF;
                    
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;
                    WHEN DUP_VAL_ON_INDEX THEN NULL;
                END;
                
                EXIT WHEN v_count >= (v_target_count - v_base_count);
            END LOOP;
        END;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('PURCHASE_FACT generation completed. Generated: ' || v_count || ' new records.');
    DBMS_OUTPUT.PUT_LINE('Total PURCHASE_FACT records: ' || (v_base_count + v_count));
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error in PURCHASE_FACT generation: ' || SQLERRM);
        RAISE;
END;
/

-- =============================================
-- RESERVATION_FACT GENERATION: 2K → 200K records
-- Patterns: Course material queues, popular book reservations
-- =============================================

CREATE OR REPLACE PROCEDURE GENERATE_RESERVATION_FACT_DATA AS
    v_count NUMBER := 0;
    v_base_count NUMBER;
    v_target_count NUMBER := 200000;
    
    CURSOR reservation_templates IS
        SELECT rf.*, d.cal_date, d.study_week_ind, d.exam_week_ind, d.cal_month
        FROM RESERVATION_FACT rf
        JOIN DATE_DIM d ON rf.reserve_start_date_key = d.date_key
        ORDER BY DBMS_RANDOM.VALUE;
        
    CURSOR popular_books IS
        SELECT DISTINCT book_key FROM LOAN_FACT
        ORDER BY DBMS_RANDOM.VALUE;
BEGIN
    SELECT COUNT(*) INTO v_base_count FROM RESERVATION_FACT;
    DBMS_OUTPUT.PUT_LINE('Starting RESERVATION_FACT generation. Current records: ' || v_base_count);
    
    -- Generate queue-based reservations for popular books
    FOR book_rec IN popular_books LOOP
        EXIT WHEN v_count >= (v_target_count - v_base_count);
        
        -- Create reservation queues (10-30 people per popular book)
        FOR queue_pos IN 1..ROUND(DBMS_RANDOM.VALUE(10, 30)) LOOP
            DECLARE
                v_random_member_key NUMBER;
                v_random_staff_key NUMBER;
                v_random_date DATE;
                v_start_date_key NUMBER;
                v_end_date_key NUMBER;
                v_status VARCHAR2(20);
            BEGIN
                -- Get random member and staff
                SELECT member_key INTO v_random_member_key
                FROM (SELECT member_key FROM MEMBER_DIM WHERE is_current_flag = '1' ORDER BY DBMS_RANDOM.VALUE)
                WHERE ROWNUM = 1;
                
                SELECT staff_key INTO v_random_staff_key
                FROM (SELECT staff_key FROM STAFF_DIM WHERE is_current_flag = '1' ORDER BY DBMS_RANDOM.VALUE)
                WHERE ROWNUM = 1;
                
                -- Random date within academic periods
                SELECT cal_date INTO v_random_date
                FROM (SELECT cal_date FROM DATE_DIM WHERE cal_year BETWEEN 2020 AND 2025 ORDER BY DBMS_RANDOM.VALUE)
                WHERE ROWNUM = 1;
                
                SELECT date_key INTO v_start_date_key
                FROM DATE_DIM WHERE cal_date = v_random_date;
                
                SELECT date_key INTO v_end_date_key
                FROM DATE_DIM WHERE cal_date = v_random_date + 7;
                
                -- Determine status based on queue position
                IF queue_pos <= 3 THEN
                    v_status := 'FULFILLED';
                ELSIF queue_pos <= 10 THEN
                    v_status := 'EXPIRED';
                ELSE
                    v_status := 'ACTIVE';
                END IF;
                
                -- Insert reservation
                INSERT INTO RESERVATION_FACT (
                    member_key, book_key, staff_key, reserve_start_date_key,
                    reserve_end_date_key, reserveID, reservationStatus, reservationDuration
                ) VALUES (
                    v_random_member_key,
                    book_rec.book_key,
                    v_random_staff_key,
                    v_start_date_key,
                    v_end_date_key,
                    'RG' || LPAD(RESERVATION_FACT_SEQ.NEXTVAL, 8, '0'),
                    v_status,
                    7
                );
                
                v_count := v_count + 1;
                
                IF MOD(v_count, 10000) = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('Generated ' || v_count || ' reservation records...');
                    COMMIT;
                END IF;
                
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
                WHEN DUP_VAL_ON_INDEX THEN NULL;
            END;
            
            EXIT WHEN v_count >= (v_target_count - v_base_count);
        END LOOP;
    END LOOP;
    
    -- Fill remaining with template-based variations
    FOR template IN reservation_templates LOOP
        EXIT WHEN v_count >= (v_target_count - v_base_count);
        
        -- Generate multiple reservations per template (course material pattern)
        FOR i IN 1..ROUND(DBMS_RANDOM.VALUE(5, 15)) LOOP
            DECLARE
                v_new_start_date DATE;
                v_new_start_key NUMBER;
                v_new_end_key NUMBER;
                v_days_offset NUMBER;
            BEGIN
                v_days_offset := ROUND(DBMS_RANDOM.VALUE(-90, 90));
                v_new_start_date := (SELECT cal_date FROM DATE_DIM WHERE date_key = template.reserve_start_date_key) + v_days_offset;
                
                SELECT date_key INTO v_new_start_key 
                FROM DATE_DIM WHERE cal_date = v_new_start_date;
                
                SELECT date_key INTO v_new_end_key 
                FROM DATE_DIM WHERE cal_date = v_new_start_date + 7;
                
                INSERT INTO RESERVATION_FACT (
                    member_key, book_key, staff_key, reserve_start_date_key,
                    reserve_end_date_key, reserveID, reservationStatus, reservationDuration
                ) VALUES (
                    template.member_key,
                    template.book_key,
                    template.staff_key,
                    v_new_start_key,
                    v_new_end_key,
                    'RG' || LPAD(RESERVATION_FACT_SEQ.NEXTVAL, 8, '0'),
                    template.reservationStatus,
                    7
                );
                
                v_count := v_count + 1;
                
                IF MOD(v_count, 10000) = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('Generated ' || v_count || ' reservation records...');
                    COMMIT;
                END IF;
                
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
                WHEN DUP_VAL_ON_INDEX THEN NULL;
            END;
            
            EXIT WHEN v_count >= (v_target_count - v_base_count);
        END LOOP;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('RESERVATION_FACT generation completed. Generated: ' || v_count || ' new records.');
    DBMS_OUTPUT.PUT_LINE('Total RESERVATION_FACT records: ' || (v_base_count + v_count));
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error in RESERVATION_FACT generation: ' || SQLERRM);
        RAISE;
END;
/

-- =============================================
-- SEQUENCES FOR GENERATED IDs
-- =============================================

-- Sequences for generated IDs (if they don't exist)
CREATE SEQUENCE LOAN_FACT_SEQ START WITH 100000;
CREATE SEQUENCE SALES_FACT_SEQ START WITH 100000;
CREATE SEQUENCE PURCHASE_FACT_SEQ START WITH 100000;
CREATE SEQUENCE RESERVATION_FACT_SEQ START WITH 100000;

-- =============================================
-- MASTER PROCEDURE TO GENERATE ALL DATA
-- =============================================

CREATE OR REPLACE PROCEDURE GENERATE_ALL_FACT_DATA AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('=================================================');
    DBMS_OUTPUT.PUT_LINE('STARTING COMPREHENSIVE FACT TABLE DATA GENERATION');
    DBMS_OUTPUT.PUT_LINE('Target: 100K+ records per fact table');
    DBMS_OUTPUT.PUT_LINE('=================================================');
    
    -- Generate in dependency order
    GENERATE_LOAN_FACT_DATA;
    GENERATE_SALES_FACT_DATA;
    GENERATE_PURCHASE_FACT_DATA;
    GENERATE_RESERVATION_FACT_DATA;
    
    DBMS_OUTPUT.PUT_LINE('=================================================');
    DBMS_OUTPUT.PUT_LINE('ALL FACT TABLE DATA GENERATION COMPLETED');
    DBMS_OUTPUT.PUT_LINE('=================================================');
    
    -- Final counts
    DECLARE
        v_loan_count NUMBER;
        v_sales_count NUMBER;
        v_purchase_count NUMBER;
        v_reservation_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_loan_count FROM LOAN_FACT;
        SELECT COUNT(*) INTO v_sales_count FROM SALES_FACT;
        SELECT COUNT(*) INTO v_purchase_count FROM PURCHASE_FACT;
        SELECT COUNT(*) INTO v_reservation_count FROM RESERVATION_FACT;
        
        DBMS_OUTPUT.PUT_LINE('FINAL RECORD COUNTS:');
        DBMS_OUTPUT.PUT_LINE('  LOAN_FACT: ' || TO_CHAR(v_loan_count, '999,999,999'));
        DBMS_OUTPUT.PUT_LINE('  SALES_FACT: ' || TO_CHAR(v_sales_count, '999,999,999'));
        DBMS_OUTPUT.PUT_LINE('  PURCHASE_FACT: ' || TO_CHAR(v_purchase_count, '999,999,999'));
        DBMS_OUTPUT.PUT_LINE('  RESERVATION_FACT: ' || TO_CHAR(v_reservation_count, '999,999,999'));
        DBMS_OUTPUT.PUT_LINE('  TOTAL: ' || TO_CHAR(v_loan_count + v_sales_count + v_purchase_count + v_reservation_count, '999,999,999'));
    END;
END;
/

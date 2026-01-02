-- 06_advanced_features.sql
-- implementing Advanced RDBMS Features for Project Requirements

USE careconnect;

-- =========================================================
-- FEATURE 1: TABLE PARTITIONING
-- Requirement D: Advanced Feature
-- Why: Audit logs grow indefinitely. Partitioning them by year improves query performance for recent logs and makes archiving easy.
-- =========================================================

-- Note: To partition an existing table, we usually redefine it. 
-- Since audit_logs might already exist, we will drop and recreate it with partitioning 
-- or Alter it if supported (MySQL often requires dropping PK to add partition key if not part of PK).

DROP TABLE IF EXISTS audit_logs;

CREATE TABLE audit_logs (
    log_id INT NOT NULL AUTO_INCREMENT,
    table_name VARCHAR(50) NOT NULL,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id INT NOT NULL,
    old_value JSON,
    new_value JSON,
    performed_by INT,
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Partitioning requires the partition key to be part of the Primary Key
    PRIMARY KEY (log_id, performed_at)
)
PARTITION BY RANGE (UNIX_TIMESTAMP(performed_at)) (
    PARTITION p_historic VALUES LESS THAN (UNIX_TIMESTAMP('2024-01-01 00:00:00')),
    PARTITION p_2024 VALUES LESS THAN (UNIX_TIMESTAMP('2025-01-01 00:00:00')),
    PARTITION p_2025 VALUES LESS THAN (UNIX_TIMESTAMP('2026-01-01 00:00:00')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- =========================================================
-- FEATURE 2: SCHEDULED EVENTS
-- Requirement D: Scheduled jobs/events
-- Why: Automatically clean up "Scheduled" appointments that have passed without being "Confirmed" or "Completed".
-- =========================================================

SET GLOBAL event_scheduler = ON;

CREATE EVENT IF NOT EXISTS evt_auto_cancel_noshows
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
DO
  UPDATE appointments
  SET status = 'NoShow'
  WHERE status = 'Scheduled' 
  AND appointment_date < DATE_SUB(NOW(), INTERVAL 2 HOUR);

-- =========================================================
-- FEATURE 3: CURSOR & COMPLEX LOGIC
-- Requirement C: Cursor usage
-- Why: Analyze patient visit history row-by-row to categorize them as 'VIP' in a separate summary table.
-- =========================================================

-- Create a summary table first
CREATE TABLE IF NOT EXISTS patient_loyalty_program (
    user_id INT PRIMARY KEY,
    total_visits INT DEFAULT 0,
    total_spent DECIMAL(10, 2) DEFAULT 0.00,
    loyalty_tier ENUM('Standard', 'Silver', 'Gold') DEFAULT 'Standard',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

CREATE PROCEDURE ProcessLoyaltyTiers()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE p_user_id INT;
    DECLARE p_visits INT;
    DECLARE p_spent DECIMAL(10,2);
    
    -- Declare Cursor
    DECLARE cur_patients CURSOR FOR 
        SELECT 
            pat.user_id, 
            COUNT(a.appointment_id) as visit_count, 
            IFNULL(SUM(i.net_amount), 0) as total_spent
        FROM patients pat
        JOIN appointments a ON pat.patient_id = a.patient_id
        LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
        WHERE a.status = 'Completed'
        GROUP BY pat.user_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur_patients;

    read_loop: LOOP
        FETCH cur_patients INTO p_user_id, p_visits, p_spent;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Logic to determine Tier
        -- Gold: > 10 visits OR > 50,000 BDT spent
        -- Silver: > 5 visits OR > 20,000 BDT spent
        -- Standard: Else
        
        -- Upsert into loyalty table
        INSERT INTO patient_loyalty_program (user_id, total_visits, total_spent, loyalty_tier)
        VALUES (p_user_id, p_visits, p_spent, 
            CASE 
                WHEN p_visits > 10 OR p_spent > 50000 THEN 'Gold'
                WHEN p_visits > 5 OR p_spent > 20000 THEN 'Silver'
                ELSE 'Standard'
            END
        )
        ON DUPLICATE KEY UPDATE
            total_visits = VALUES(total_visits),
            total_spent = VALUES(total_spent),
            loyalty_tier = VALUES(loyalty_tier),
            last_updated = NOW();
            
    END LOOP;

    CLOSE cur_patients;
END //

DELIMITER ;

-- =========================================================
-- FEATURE 4: FULL-TEXT SEARCH
-- Requirement B: Indexing strategies (Advanced)
-- Why: Allow doctors to search "headache", "fever" etc efficiently.
-- =========================================================

-- Adding Full Text Index to Medical Records
ALTER TABLE medical_records ADD FULLTEXT INDEX ft_diagnosis_symptoms (diagnosis, symptoms);

-- Example Query Usage (Commented out):
-- SELECT * FROM medical_records WHERE MATCH(diagnosis, symptoms) AGAINST('fever headache' IN NATURAL LANGUAGE MODE);


-- =========================================================
-- FEATURE 5: FINANCIAL REPORTING (Pre-calculated)
-- Requirement: Revenue calculated Yearly, Monthly, Weekly
-- =========================================================

-- 1. Create Summary Table
CREATE TABLE IF NOT EXISTS financial_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    report_type ENUM('Yearly', 'Monthly', 'Weekly') NOT NULL,
    period_label VARCHAR(50) NOT NULL, -- '2025', '2025-01', '2025-W01'
    total_revenue DECIMAL(15, 2) DEFAULT 0.00,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_report (report_type, period_label)
);

DELIMITER //

-- 2. Procedure to Backfill/Recalculate Logic
CREATE PROCEDURE RecalculateFinancialReports()
BEGIN
    -- Clear existing to avoid double counting during full recalc
    TRUNCATE TABLE financial_reports;

    -- A. YEARLY
    -- From Payments
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT 'Yearly', DATE_FORMAT(payment_date, '%Y'), SUM(amount)
    FROM payments
    GROUP BY DATE_FORMAT(payment_date, '%Y');
    
    -- From Paid Test Invoices (Direct Invoice, No Payment entries traditionally in this schema for some flows)
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT 'Yearly', DATE_FORMAT(generated_at, '%Y'), SUM(net_amount)
    FROM invoices 
    WHERE status = 'Paid' AND test_record_id IS NOT NULL
    GROUP BY DATE_FORMAT(generated_at, '%Y')
    ON DUPLICATE KEY UPDATE total_revenue = total_revenue + VALUES(total_revenue);

    -- B. MONTHLY
    -- From Payments
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT 'Monthly', DATE_FORMAT(payment_date, '%Y-%m'), SUM(amount)
    FROM payments
    GROUP BY DATE_FORMAT(payment_date, '%Y-%m');

    -- From Paid Test Invoices
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT 'Monthly', DATE_FORMAT(generated_at, '%Y-%m'), SUM(net_amount)
    FROM invoices 
    WHERE status = 'Paid' AND test_record_id IS NOT NULL
    GROUP BY DATE_FORMAT(generated_at, '%Y-%m')
    ON DUPLICATE KEY UPDATE total_revenue = total_revenue + VALUES(total_revenue);

    -- C. WEEKLY
    -- From Payments
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT 'Weekly', DATE_FORMAT(payment_date, '%x-W%v'), SUM(amount)
    FROM payments
    GROUP BY DATE_FORMAT(payment_date, '%x-W%v');

    -- From Paid Test Invoices
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT 'Weekly', DATE_FORMAT(generated_at, '%x-W%v'), SUM(net_amount)
    FROM invoices 
    WHERE status = 'Paid' AND test_record_id IS NOT NULL
    GROUP BY DATE_FORMAT(generated_at, '%x-W%v')
    ON DUPLICATE KEY UPDATE total_revenue = total_revenue + VALUES(total_revenue);

END //

-- 3. Triggers for Real-time Updates

-- Trigger on Payments Insert
CREATE TRIGGER trg_update_financials_on_payment
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    -- Update Yearly
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    VALUES ('Yearly', DATE_FORMAT(NEW.payment_date, '%Y'), NEW.amount)
    ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.amount;

    -- Update Monthly
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    VALUES ('Monthly', DATE_FORMAT(NEW.payment_date, '%Y-%m'), NEW.amount)
    ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.amount;

    -- Update Weekly
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    VALUES ('Weekly', DATE_FORMAT(NEW.payment_date, '%x-W%v'), NEW.amount)
    ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.amount;
END //

-- Trigger on Invoices (Specifically for Tests that are paid)
-- Note: 'payments' table handles most money, but 'patient_tests' flow might just update invoice status.
-- However, if `ConfirmPayment` is used, it inserts into `payments`.
-- The only case we need to catch here is if `invoices` is marked PAID without `payments` insert (e.g. Test flow).
-- In `trg_create_test_invoice` (02_procedures), it inserts into `invoices` with 'Paid'.
-- It does NOT insert into `payments`. So we validly need this trigger or logic.

CREATE TRIGGER trg_update_financials_on_invoice
AFTER INSERT ON invoices
FOR EACH ROW
BEGIN
    IF NEW.status = 'Paid' AND NEW.test_record_id IS NOT NULL THEN
         -- Upate Yearly
        INSERT INTO financial_reports (report_type, period_label, total_revenue)
        VALUES ('Yearly', DATE_FORMAT(NEW.generated_at, '%Y'), NEW.net_amount)
        ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.net_amount;

        -- Update Monthly
        INSERT INTO financial_reports (report_type, period_label, total_revenue)
        VALUES ('Monthly', DATE_FORMAT(NEW.generated_at, '%Y-%m'), NEW.net_amount)
        ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.net_amount;

        -- Update Weekly
        INSERT INTO financial_reports (report_type, period_label, total_revenue)
        VALUES ('Weekly', DATE_FORMAT(NEW.generated_at, '%x-W%v'), NEW.net_amount)
        ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.net_amount;
    END IF;
END //

DELIMITER ;

-- 4. Initial Population (Backfill for existing seed data)
CALL RecalculateFinancialReports();

-- ============================================================================
-- EXTENDED ADVANCED FEATURES AND UTILITY LOGIC (NON-INTRUSIVE)
-- These are additional advanced procedures, functions, and utilities
-- They DO NOT affect the main system functionality above
-- ============================================================================

-- ============================================================================
-- SECTION 1: ADVANCED DATA MINING AND PATTERN RECOGNITION
-- ============================================================================

-- Procedure: Mine Patient Disease Patterns
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_mine_disease_patterns(
    IN p_min_occurrences INT,
    IN p_time_window_days INT
)
BEGIN
    -- Identify common disease combinations and patterns
    SELECT 
        'Disease Co-occurrence Analysis' AS analysis_type,
        mr1.diagnosis AS primary_diagnosis,
        mr2.diagnosis AS co_occurring_diagnosis,
        COUNT(DISTINCT a1.patient_id) AS patient_count,
        ROUND(AVG(DATEDIFF(a2.appointment_date, a1.appointment_date)), 1) AS avg_days_between_diagnoses,
        ROUND(
            COUNT(DISTINCT a1.patient_id) * 100.0 / 
            (SELECT COUNT(DISTINCT patient_id) FROM appointments WHERE status = 'Completed'),
            4
        ) AS prevalence_rate_percent,
        GROUP_CONCAT(DISTINCT dept.name SEPARATOR ', ') AS departments_involved
    FROM medical_records mr1
    JOIN appointments a1 ON mr1.appointment_id = a1.appointment_id
    JOIN medical_records mr2 ON mr2.appointment_id IN (
        SELECT a2.appointment_id 
        FROM appointments a2 
        WHERE a2.patient_id = a1.patient_id
        AND a2.appointment_id != a1.appointment_id
        AND ABS(DATEDIFF(a2.appointment_date, a1.appointment_date)) <= p_time_window_days
    )
    JOIN appointments a2 ON mr2.appointment_id = a2.appointment_id
    JOIN doctors d ON a1.doctor_id = d.doctor_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    WHERE mr1.diagnosis IS NOT NULL 
    AND mr2.diagnosis IS NOT NULL
    AND mr1.diagnosis != mr2.diagnosis
    GROUP BY mr1.diagnosis, mr2.diagnosis
    HAVING patient_count >= p_min_occurrences
    ORDER BY patient_count DESC, prevalence_rate_percent DESC
    LIMIT 50;
    
    -- Seasonal disease patterns
    SELECT 
        'Seasonal Disease Patterns' AS analysis_type,
        mr.diagnosis,
        MONTHNAME(a.appointment_date) AS month_name,
        MONTH(a.appointment_date) AS month_num,
        COUNT(*) AS case_count,
        COUNT(DISTINCT a.patient_id) AS unique_patients,
        ROUND(AVG(TIMESTAMPDIFF(YEAR, pr.date_of_birth, a.appointment_date)), 1) AS avg_patient_age
    FROM medical_records mr
    JOIN appointments a ON mr.appointment_id = a.appointment_id
    JOIN patients p ON a.patient_id = p.patient_id
    JOIN profiles pr ON p.user_id = pr.user_id
    WHERE mr.diagnosis IS NOT NULL
    AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 24 MONTH)
    GROUP BY mr.diagnosis, month_name, month_num
    HAVING case_count >= 3
    ORDER BY mr.diagnosis, month_num;
END //
DELIMITER ;

-- Procedure: Predictive Health Risk Modeling
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_predictive_health_risk_model()
BEGIN
    -- Create risk prediction model based on historical patterns
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_health_risk_predictions (
        patient_id INT,
        patient_name VARCHAR(200),
        age INT,
        gender VARCHAR(20),
        predicted_risk_conditions TEXT,
        risk_probability DECIMAL(5,2),
        prevention_recommendations TEXT,
        next_recommended_checkup DATE
    );
    
    TRUNCATE TABLE tmp_health_risk_predictions;
    
    -- Identify patients at risk based on age, gender, family history patterns
    INSERT INTO tmp_health_risk_predictions
    SELECT 
        p.patient_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS patient_name,
        TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) AS age,
        pr.gender,
        CASE 
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) > 50 AND pr.gender = 'Male' THEN 'Heart Disease, Diabetes, Prostate Issues'
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) > 50 AND pr.gender = 'Female' THEN 'Osteoporosis, Breast Cancer, Heart Disease'
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 30 AND 50 THEN 'Diabetes, Hypertension, Obesity'
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) < 30 THEN 'Infectious Diseases, Mental Health, Accidents'
            ELSE 'General Health Monitoring'
        END AS predicted_risk_conditions,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM medical_records mr
                JOIN appointments a ON mr.appointment_id = a.appointment_id
                WHERE a.patient_id = p.patient_id
                AND (LOWER(mr.diagnosis) LIKE '%diabetes%' OR LOWER(mr.diagnosis) LIKE '%hypertension%')
            ) THEN 75.00
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) > 60 THEN 45.00
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) > 40 THEN 30.00
            ELSE 15.00
        END AS risk_probability,
        CASE 
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) > 50 THEN 'Annual comprehensive health screening, cardiac evaluation, cancer screening'
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) > 30 THEN 'Biennial health check, lifestyle counseling, metabolic panel'
            ELSE 'Basic health monitoring, vaccination updates, lifestyle guidance'
        END AS prevention_recommendations,
        CASE 
            WHEN MAX(a.appointment_date) IS NULL THEN DATE_ADD(CURDATE(), INTERVAL 1 MONTH)
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 365 THEN CURDATE()
            ELSE DATE_ADD(MAX(a.appointment_date), INTERVAL 6 MONTH)
        END AS next_recommended_checkup
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.user_id
    LEFT JOIN appointments a ON p.patient_id = a.patient_id
    WHERE pr.date_of_birth IS NOT NULL
    GROUP BY p.patient_id, pr.first_name, pr.last_name, pr.date_of_birth, pr.gender;
    
    -- Return predictions
    SELECT * FROM tmp_health_risk_predictions
    ORDER BY risk_probability DESC, age DESC;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_health_risk_predictions;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 2: ADVANCED RESOURCE ALLOCATION AND OPTIMIZATION
-- ============================================================================

-- Procedure: Dynamic Resource Allocation Optimizer
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_optimize_resource_allocation(
    IN p_optimization_date DATE
)
BEGIN
    DECLARE v_total_doctors INT;
    DECLARE v_total_rooms INT;
    DECLARE v_expected_appointments INT;
    
    -- Calculate expected demand
    SELECT COUNT(*) INTO v_expected_appointments
    FROM appointments
    WHERE DATE(appointment_date) = p_optimization_date;
    
    SELECT COUNT(*) INTO v_total_doctors
    FROM doctors WHERE EXISTS (
        SELECT 1 FROM users u WHERE u.user_id = doctors.user_id AND u.is_active = TRUE
    );
    
    SELECT COUNT(DISTINCT room_number) INTO v_total_rooms
    FROM schedules WHERE room_number IS NOT NULL;
    
    -- Department-wise allocation recommendations
    SELECT 
        'Department Resource Allocation' AS report_section,
        dept.name AS department,
        COUNT(DISTINCT d.doctor_id) AS current_doctors,
        COUNT(DISTINCT s.schedule_id) AS current_schedule_slots,
        COALESCE(COUNT(a.appointment_id), 0) AS appointments_on_date,
        ROUND(
            COALESCE(COUNT(a.appointment_id), 0) / NULLIF(COUNT(DISTINCT d.doctor_id), 0),
            2
        ) AS appointments_per_doctor,
        CASE 
            WHEN COALESCE(COUNT(a.appointment_id), 0) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 12 THEN 'Add 1-2 doctors or extend hours'
            WHEN COALESCE(COUNT(a.appointment_id), 0) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 8 THEN 'Optimal allocation'
            WHEN COALESCE(COUNT(a.appointment_id), 0) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 4 THEN 'Slight underutilization'
            WHEN COUNT(DISTINCT d.doctor_id) > 0 THEN 'Consider reducing staff or promoting services'
            ELSE 'No data available'
        END AS allocation_recommendation,
        CASE 
            WHEN COALESCE(COUNT(a.appointment_id), 0) > COUNT(DISTINCT s.schedule_id) * 0.9 THEN 'High'
            WHEN COALESCE(COUNT(a.appointment_id), 0) > COUNT(DISTINCT s.schedule_id) * 0.7 THEN 'Moderate'
            ELSE 'Low'
        END AS capacity_utilization
    FROM departments dept
    JOIN doctors d ON dept.dept_id = d.dept_id
    LEFT JOIN schedules s ON d.doctor_id = s.doctor_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id 
        AND DATE(a.appointment_date) = p_optimization_date
    GROUP BY dept.dept_id, dept.name
    ORDER BY appointments_on_date DESC;
    
    -- Room allocation optimization
    SELECT 
        'Room Allocation Optimization' AS report_section,
        s.room_number,
        COUNT(DISTINCT s.doctor_id) AS doctors_assigned,
        COUNT(DISTINCT rb.booking_id) AS bookings_on_date,
        COALESCE(SUM(rb.hours), 0) AS total_hours_booked,
        24 - COALESCE(SUM(rb.hours), 0) AS available_hours,
        CASE 
            WHEN COALESCE(SUM(rb.hours), 0) >= 20 THEN 'Fully Utilized - Consider additional room'
            WHEN COALESCE(SUM(rb.hours), 0) >= 16 THEN 'Well Utilized'
            WHEN COALESCE(SUM(rb.hours), 0) >= 8 THEN 'Moderate Utilization'
            ELSE 'Underutilized - Consider consolidation'
        END AS utilization_status
    FROM schedules s
    LEFT JOIN room_bookings rb ON s.room_number = rb.room_id 
        AND DATE(rb.booking_date) = p_optimization_date
    WHERE s.room_number IS NOT NULL
    GROUP BY s.room_number
    ORDER BY total_hours_booked DESC;
    
    -- Overall system capacity report
    SELECT 
        'System Capacity Overview' AS report_section,
        v_total_doctors AS total_active_doctors,
        v_total_rooms AS total_available_rooms,
        v_expected_appointments AS expected_appointments,
        ROUND(v_expected_appointments / NULLIF(v_total_doctors, 0), 2) AS appointments_per_doctor_ratio,
        CASE 
            WHEN v_expected_appointments / NULLIF(v_total_doctors, 0) > 15 THEN 'System Overload - Immediate Action Required'
            WHEN v_expected_appointments / NULLIF(v_total_doctors, 0) > 10 THEN 'High Load - Monitor Closely'
            WHEN v_expected_appointments / NULLIF(v_total_doctors, 0) > 5 THEN 'Normal Load'
            ELSE 'Low Load - Capacity Available'
        END AS system_status;
END //
DELIMITER ;

-- Procedure: Staff Workload Balancing
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_balance_staff_workload(
    IN p_target_date DATE,
    IN p_weeks_history INT
)
BEGIN
    -- Analyze workload distribution and suggest rebalancing
    SELECT 
        d.doctor_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS doctor_name,
        dept.name AS department,
        d.specialization,
        COUNT(a.appointment_id) AS appointments_in_period,
        ROUND(COUNT(a.appointment_id) / p_weeks_history, 2) AS avg_weekly_appointments,
        SUM(i.net_amount) AS revenue_generated,
        COUNT(DISTINCT a.patient_id) AS unique_patients_served,
        ROUND(
            COUNT(a.appointment_id) / NULLIF(
                (SELECT AVG(doc_count) FROM (
                    SELECT COUNT(*) as doc_count 
                    FROM appointments a2
                    JOIN doctors d2 ON a2.doctor_id = d2.doctor_id
                    WHERE d2.dept_id = d.dept_id
                    AND a2.appointment_date >= DATE_SUB(p_target_date, INTERVAL p_weeks_history WEEK)
                    GROUP BY d2.doctor_id
                ) dept_avg),
                0
            ) * 100,
            2
        ) AS workload_vs_dept_avg_percent,
        CASE 
            WHEN COUNT(a.appointment_id) / p_weeks_history > 15 THEN 'Overloaded - Redistribute patients'
            WHEN COUNT(a.appointment_id) / p_weeks_history > 10 THEN 'High Load - Monitor for burnout'
            WHEN COUNT(a.appointment_id) / p_weeks_history > 5 THEN 'Balanced Workload'
            WHEN COUNT(a.appointment_id) / p_weeks_history > 2 THEN 'Underutilized - Increase availability'
            ELSE 'Very Low - Review schedule or availability'
        END AS workload_assessment,
        CASE 
            WHEN COUNT(a.appointment_id) / p_weeks_history > 15 THEN 'Reduce weekly slots by 20%'
            WHEN COUNT(a.appointment_id) / p_weeks_history < 3 THEN 'Increase marketing, add more slots'
            ELSE 'Maintain current schedule'
        END AS recommended_action
    FROM doctors d
    JOIN profiles pr ON d.user_id = pr.user_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
        AND a.appointment_date >= DATE_SUB(p_target_date, INTERVAL p_weeks_history WEEK)
        AND a.appointment_date <= p_target_date
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    GROUP BY d.doctor_id, pr.first_name, pr.last_name, dept.name, d.specialization, d.dept_id
    ORDER BY appointments_in_period DESC;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 3: ADVANCED FINANCIAL INTELLIGENCE
-- ============================================================================

-- Procedure: Break-Even Analysis by Department
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_department_breakeven_analysis()
BEGIN
    -- Calculate break-even points for each department
    SELECT 
        dept.name AS department,
        COUNT(DISTINCT d.doctor_id) AS doctors_count,
        -- Estimated monthly fixed costs (salaries, overhead)
        COUNT(DISTINCT d.doctor_id) * 50000 AS estimated_monthly_fixed_costs,
        COUNT(a.appointment_id) AS appointments_last_30_days,
        SUM(i.net_amount) AS revenue_last_30_days,
        ROUND(AVG(i.net_amount), 2) AS avg_revenue_per_appointment,
        -- Break-even calculation: Fixed costs / (Revenue per unit - Variable cost per unit)
        -- Assuming 20% variable cost
        ROUND(
            (COUNT(DISTINCT d.doctor_id) * 50000) / 
            NULLIF(AVG(i.net_amount) * 0.8, 0),
            0
        ) AS monthly_appointments_needed_for_breakeven,
        CASE 
            WHEN COUNT(a.appointment_id) >= 
                (COUNT(DISTINCT d.doctor_id) * 50000) / NULLIF(AVG(i.net_amount) * 0.8, 0)
            THEN 'Profitable'
            WHEN COUNT(a.appointment_id) >= 
                ((COUNT(DISTINCT d.doctor_id) * 50000) / NULLIF(AVG(i.net_amount) * 0.8, 0)) * 0.8
            THEN 'Near Break-even'
            ELSE 'Below Break-even'
        END AS profitability_status,
        ROUND(
            (SUM(i.net_amount) - (COUNT(DISTINCT d.doctor_id) * 50000)) / 
            NULLIF(COUNT(DISTINCT d.doctor_id) * 50000, 0) * 100,
            2
        ) AS profit_margin_percent
    FROM departments dept
    JOIN doctors d ON dept.dept_id = d.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
        AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    GROUP BY dept.dept_id, dept.name
    ORDER BY profit_margin_percent DESC;
END //
DELIMITER ;

-- Procedure: Revenue Leakage Detection
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_detect_revenue_leakage()
BEGIN
    -- Identify potential revenue loss points
    
    -- 1. Completed appointments without invoices
    SELECT 
        'Appointments Without Invoices' AS leakage_category,
        COUNT(*) AS count,
        COUNT(*) * (SELECT AVG(net_amount) FROM invoices WHERE status = 'Paid') AS estimated_revenue_loss,
        'Create invoices immediately' AS recommended_action
    FROM appointments a
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
    WHERE a.status = 'Completed'
    AND i.invoice_id IS NULL
    AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY);
    
    -- 2. Pending invoices aging analysis
    SELECT 
        'Aging Pending Invoices' AS leakage_category,
        CASE 
            WHEN DATEDIFF(CURDATE(), generated_at) > 90 THEN 'Over 90 Days'
            WHEN DATEDIFF(CURDATE(), generated_at) > 60 THEN '60-90 Days'
            WHEN DATEDIFF(CURDATE(), generated_at) > 30 THEN '30-60 Days'
            ELSE 'Under 30 Days'
        END AS aging_bucket,
        COUNT(*) AS invoice_count,
        SUM(net_amount) AS total_outstanding,
        ROUND(AVG(net_amount), 2) AS avg_invoice_amount,
        CASE 
            WHEN DATEDIFF(CURDATE(), generated_at) > 90 THEN 'Send to collections'
            WHEN DATEDIFF(CURDATE(), generated_at) > 60 THEN 'Final notice'
            WHEN DATEDIFF(CURDATE(), generated_at) > 30 THEN 'Second reminder'
            ELSE 'First reminder'
        END AS collection_strategy
    FROM invoices
    WHERE status = 'Pending'
    GROUP BY aging_bucket
    ORDER BY total_outstanding DESC;
    
    -- 3. Discount abuse analysis
    SELECT 
        'High Discount Patterns' AS leakage_category,
        CONCAT(pr.first_name, ' ', pr.last_name) AS authorized_by,
        u.role,
        COUNT(i.invoice_id) AS invoices_with_discount,
        ROUND(AVG(i.discount_amount), 2) AS avg_discount_amount,
        ROUND(AVG(i.discount_amount / NULLIF(i.total_amount, 0) * 100), 2) AS avg_discount_percent,
        SUM(i.discount_amount) AS total_discount_given,
        CASE 
            WHEN AVG(i.discount_amount / NULLIF(i.total_amount, 0) * 100) > 20 THEN 'Review discount policy'
            WHEN AVG(i.discount_amount / NULLIF(i.total_amount, 0) * 100) > 10 THEN 'Monitor closely'
            ELSE 'Within acceptable range'
        END AS audit_recommendation
    FROM invoices i
    JOIN appointments a ON i.appointment_id = a.appointment_id
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN users u ON d.user_id = u.user_id
    JOIN profiles pr ON u.user_id = pr.user_id
    WHERE i.discount_amount > 0
    AND i.generated_at >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
    GROUP BY pr.first_name, pr.last_name, u.role
    HAVING total_discount_given > 5000
    ORDER BY total_discount_given DESC;
    
    -- 4. No-show cost analysis
    SELECT 
        'No-Show Revenue Loss' AS leakage_category,
        COUNT(*) AS total_noshows,
        COUNT(*) * (SELECT AVG(consultation_fee) FROM doctors) AS estimated_lost_revenue,
        ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM appointments WHERE appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)), 2) AS noshow_rate_percent,
        'Implement no-show fee policy' AS recommended_action
    FROM appointments
    WHERE status = 'NoShow'
    AND appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY);
END //
DELIMITER ;

-- Procedure: Dynamic Pricing Recommendations
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_dynamic_pricing_recommendations()
BEGIN
    -- Analyze pricing elasticity and suggest optimizations
    SELECT 
        dept.name AS department,
        d.specialization,
        COUNT(DISTINCT d.doctor_id) AS doctors_in_category,
        ROUND(AVG(d.consultation_fee), 2) AS current_avg_fee,
        ROUND(MIN(d.consultation_fee), 2) AS min_fee,
        ROUND(MAX(d.consultation_fee), 2) AS max_fee,
        COUNT(a.appointment_id) AS appointments_last_90_days,
        ROUND(AVG(i.net_amount), 2) AS avg_total_invoice,
        -- Demand-based pricing suggestion
        CASE 
            WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 40 THEN 'High Demand - Consider 10-15% price increase'
            WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 25 THEN 'Good Demand - Maintain pricing'
            WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 10 THEN 'Moderate Demand - Consider promotional pricing'
            ELSE 'Low Demand - Implement discount strategy'
        END AS pricing_recommendation,
        ROUND(
            CASE 
                WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 40 THEN AVG(d.consultation_fee) * 1.125
                WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 25 THEN AVG(d.consultation_fee)
                WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 10 THEN AVG(d.consultation_fee) * 0.9
                ELSE AVG(d.consultation_fee) * 0.8
            END,
            2
        ) AS suggested_new_fee,
        ROUND(
            (CASE 
                WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 40 THEN AVG(d.consultation_fee) * 1.125
                WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 25 THEN AVG(d.consultation_fee)
                WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 10 THEN AVG(d.consultation_fee) * 0.9
                ELSE AVG(d.consultation_fee) * 0.8
            END - AVG(d.consultation_fee)) * COUNT(a.appointment_id) / 3,
            2
        ) AS estimated_quarterly_revenue_impact
    FROM departments dept
    JOIN doctors d ON dept.dept_id = d.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
        AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
    GROUP BY dept.name, d.specialization
    ORDER BY appointments_last_90_days DESC;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 4: ADVANCED PATIENT ENGAGEMENT AND RETENTION
-- ============================================================================

-- Procedure: Patient Segmentation for Targeted Marketing
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_segment_patients_for_marketing()
BEGIN
    -- Create patient segments for targeted campaigns
    SELECT 
        segment_name,
        COUNT(*) AS patient_count,
        ROUND(AVG(total_visits), 2) AS avg_visits,
        ROUND(AVG(total_spent), 2) AS avg_lifetime_value,
        ROUND(AVG(days_since_last_visit), 0) AS avg_days_inactive,
        campaign_recommendation,
        offer_suggestion
    FROM (
        SELECT 
            p.patient_id,
            CONCAT(pr.first_name, ' ', pr.last_name) AS patient_name,
            COUNT(a.appointment_id) AS total_visits,
            COALESCE(SUM(i.net_amount), 0) AS total_spent,
            COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) AS days_since_last_visit,
            CASE 
                WHEN COUNT(a.appointment_id) >= 10 AND COALESCE(SUM(i.net_amount), 0) >= 50000 
                    AND COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) <= 60
                THEN 'VIP Active'
                WHEN COUNT(a.appointment_id) >= 10 AND COALESCE(SUM(i.net_amount), 0) >= 50000
                THEN 'VIP At Risk'
                WHEN COUNT(a.appointment_id) >= 5 AND COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) <= 90
                THEN 'Regular Active'
                WHEN COUNT(a.appointment_id) >= 5
                THEN 'Regular At Risk'
                WHEN COUNT(a.appointment_id) >= 2 AND COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) <= 180
                THEN 'Occasional Active'
                WHEN COUNT(a.appointment_id) >= 2
                THEN 'Occasional Dormant'
                WHEN COUNT(a.appointment_id) = 1 AND COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) <= 90
                THEN 'New Patient'
                ELSE 'Inactive'
            END AS segment_name,
            CASE 
                WHEN COUNT(a.appointment_id) >= 10 AND COALESCE(SUM(i.net_amount), 0) >= 50000 
                    AND COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) <= 60
                THEN 'Personalized health packages, priority services'
                WHEN COUNT(a.appointment_id) >= 10 AND COALESCE(SUM(i.net_amount), 0) >= 50000
                THEN 'Re-engagement with exclusive offers'
                WHEN COUNT(a.appointment_id) >= 5 AND COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) <= 90
                THEN 'Loyalty rewards, preventive care packages'
                WHEN COUNT(a.appointment_id) >= 5
                THEN 'Win-back campaign with special pricing'
                WHEN COUNT(a.appointment_id) >= 2 AND COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) <= 180
                THEN 'Regular health reminders, wellness tips'
                WHEN COUNT(a.appointment_id) >= 2
                THEN 'Reactivation campaign with incentives'
                WHEN COUNT(a.appointment_id) = 1 AND COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) <= 90
                THEN 'Onboarding sequence, follow-up appointment'
                ELSE 'Final reactivation attempt or archive'
            END AS campaign_recommendation,
            CASE 
                WHEN COUNT(a.appointment_id) >= 10 AND COALESCE(SUM(i.net_amount), 0) >= 50000 
                THEN '20% off comprehensive health package'
                WHEN COUNT(a.appointment_id) >= 5
                THEN '15% off next 3 visits'
                WHEN COUNT(a.appointment_id) >= 2
                THEN 'Free health consultation'
                ELSE '10% off first visit'
            END AS offer_suggestion
        FROM patients p
        JOIN profiles pr ON p.user_id = pr.user_id
        LEFT JOIN appointments a ON p.patient_id = a.patient_id
        LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
        GROUP BY p.patient_id, pr.first_name, pr.last_name
    ) segments
    GROUP BY segment_name, campaign_recommendation, offer_suggestion
    ORDER BY avg_lifetime_value DESC;
END //
DELIMITER ;

-- Procedure: Patient Satisfaction Prediction Model
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_predict_patient_satisfaction()
BEGIN
    -- Predictive model for patient satisfaction based on behavioral indicators
    SELECT 
        p.patient_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS patient_name,
        COUNT(a.appointment_id) AS total_appointments,
        COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) AS completed_appointments,
        COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) AS cancelled_appointments,
        ROUND(
            COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0 / 
            NULLIF(COUNT(a.appointment_id), 0),
            2
        ) AS completion_rate,
        COUNT(DISTINCT a.doctor_id) AS different_doctors_seen,
        ROUND(AVG(DATEDIFF(a.appointment_date, a.created_at)), 1) AS avg_booking_lead_time,
        COALESCE(MAX(a.appointment_date), u.created_at) AS last_interaction_date,
        DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) AS days_since_last_interaction,
        -- Satisfaction score calculation (0-100)
        ROUND(
            (
                -- Completion rate factor (40 points)
                (COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 40.0 / 
                    NULLIF(COUNT(a.appointment_id), 0)) +
                -- Loyalty factor (30 points)
                (CASE 
                    WHEN COUNT(DISTINCT a.doctor_id) = 1 AND COUNT(a.appointment_id) > 3 THEN 30
                    WHEN COUNT(DISTINCT a.doctor_id) <= 2 AND COUNT(a.appointment_id) > 2 THEN 20
                    ELSE 10
                END) +
                -- Recency factor (20 points)
                (CASE 
                    WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 30 THEN 20
                    WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 90 THEN 15
                    WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 180 THEN 10
                    ELSE 5
                END) +
                -- Engagement factor (10 points)
                (LEAST(COUNT(a.appointment_id), 10))
            ),
            2
        ) AS predicted_satisfaction_score,
        CASE 
            WHEN ROUND(
                (
                    (COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 40.0 / 
                        NULLIF(COUNT(a.appointment_id), 0)) +
                    (CASE 
                        WHEN COUNT(DISTINCT a.doctor_id) = 1 AND COUNT(a.appointment_id) > 3 THEN 30
                        WHEN COUNT(DISTINCT a.doctor_id) <= 2 AND COUNT(a.appointment_id) > 2 THEN 20
                        ELSE 10
                    END) +
                    (CASE 
                        WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 30 THEN 20
                        WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 90 THEN 15
                        WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 180 THEN 10
                        ELSE 5
                    END) +
                    (LEAST(COUNT(a.appointment_id), 10))
                ),
                2
            ) >= 80 THEN 'Highly Satisfied - Brand Ambassador Potential'
            WHEN ROUND(
                (
                    (COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 40.0 / 
                        NULLIF(COUNT(a.appointment_id), 0)) +
                    (CASE 
                        WHEN COUNT(DISTINCT a.doctor_id) = 1 AND COUNT(a.appointment_id) > 3 THEN 30
                        WHEN COUNT(DISTINCT a.doctor_id) <= 2 AND COUNT(a.appointment_id) > 2 THEN 20
                        ELSE 10
                    END) +
                    (CASE 
                        WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 30 THEN 20
                        WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 90 THEN 15
                        WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 180 THEN 10
                        ELSE 5
                    END) +
                    (LEAST(COUNT(a.appointment_id), 10))
                ),
                2
            ) >= 60 THEN 'Satisfied - Maintain Relationship'
            WHEN ROUND(
                (
                    (COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 40.0 / 
                        NULLIF(COUNT(a.appointment_id), 0)) +
                    (CASE 
                        WHEN COUNT(DISTINCT a.doctor_id) = 1 AND COUNT(a.appointment_id) > 3 THEN 30
                        WHEN COUNT(DISTINCT a.doctor_id) <= 2 AND COUNT(a.appointment_id) > 2 THEN 20
                        ELSE 10
                    END) +
                    (CASE 
                        WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 30 THEN 20
                        WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 90 THEN 15
                        WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) <= 180 THEN 10
                        ELSE 5
                    END) +
                    (LEAST(COUNT(a.appointment_id), 10))
                ),
                2
            ) >= 40 THEN 'Neutral - Improvement Needed'
            ELSE 'At Risk - Immediate Intervention Required'
        END AS satisfaction_category,
        CASE 
            WHEN COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) * 100.0 / 
                NULLIF(COUNT(a.appointment_id), 0) > 30 THEN 'Investigate cancellation reasons urgently'
            WHEN DATEDIFF(CURDATE(), COALESCE(MAX(a.appointment_date), u.created_at)) > 180 THEN 'Re-engagement campaign required'
            WHEN COUNT(DISTINCT a.doctor_id) > 5 THEN 'Lack of continuity - assign preferred doctor'
            WHEN COUNT(a.appointment_id) = 1 THEN 'Follow-up for second visit critical'
            ELSE 'Continue standard care with quality monitoring'
        END AS recommended_action
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.user_id
    JOIN users u ON p.user_id = u.user_id
    LEFT JOIN appointments a ON p.patient_id = a.patient_id
    GROUP BY p.patient_id, pr.first_name, pr.last_name, u.created_at
    ORDER BY predicted_satisfaction_score ASC, total_appointments DESC
    LIMIT 100;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 5: ADVANCED CLINICAL DECISION SUPPORT
-- ============================================================================

-- Procedure: Clinical Pathway Recommendation Engine
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_recommend_clinical_pathway(
    IN p_patient_id INT,
    IN p_primary_complaint TEXT
)
BEGIN
    DECLARE v_patient_age INT;
    DECLARE v_gender VARCHAR(20);
    DECLARE v_has_chronic_conditions BOOLEAN DEFAULT FALSE;
    
    -- Get patient demographics
    SELECT 
        TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()),
        pr.gender
    INTO v_patient_age, v_gender
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.user_id
    WHERE p.patient_id = p_patient_id;
    
    -- Check chronic conditions
    SELECT COUNT(*) > 0 INTO v_has_chronic_conditions
    FROM medical_records mr
    JOIN appointments a ON mr.appointment_id = a.appointment_id
    WHERE a.patient_id = p_patient_id
    AND LOWER(mr.diagnosis) LIKE '%chronic%';
    
    -- Recommend clinical pathway
    SELECT 
        'Clinical Pathway Recommendation' AS recommendation_type,
        p_primary_complaint AS chief_complaint,
        CASE 
            WHEN LOWER(p_primary_complaint) LIKE '%chest pain%' THEN 'Cardiology Emergency Protocol'
            WHEN LOWER(p_primary_complaint) LIKE '%shortness of breath%' THEN 'Respiratory Assessment Protocol'
            WHEN LOWER(p_primary_complaint) LIKE '%abdominal pain%' THEN 'Gastrointestinal Evaluation Protocol'
            WHEN LOWER(p_primary_complaint) LIKE '%headache%' THEN 'Neurological Assessment Protocol'
            WHEN LOWER(p_primary_complaint) LIKE '%fever%' THEN 'Infectious Disease Workup Protocol'
            ELSE 'General Medical Evaluation'
        END AS recommended_pathway,
        CASE 
            WHEN LOWER(p_primary_complaint) LIKE '%chest pain%' THEN 'ECG, Cardiac Enzymes, Chest X-Ray'
            WHEN LOWER(p_primary_complaint) LIKE '%shortness of breath%' THEN 'Pulse Oximetry, Chest X-Ray, Pulmonary Function Test'
            WHEN LOWER(p_primary_complaint) LIKE '%abdominal pain%' THEN 'CBC, LFT, Ultrasound Abdomen'
            WHEN LOWER(p_primary_complaint) LIKE '%headache%' THEN 'Neurological Exam, CT Scan if indicated'
            WHEN LOWER(p_primary_complaint) LIKE '%fever%' THEN 'CBC, Blood Culture, Urinalysis'
            ELSE 'Complete Physical Examination, Basic Labs'
        END AS recommended_tests,
        CASE 
            WHEN v_has_chronic_conditions THEN 'Review chronic disease management plan'
            WHEN v_patient_age > 60 THEN 'Consider geriatric assessment'
            WHEN v_patient_age < 18 THEN 'Pediatric protocol considerations'
            ELSE 'Standard adult protocol'
        END AS special_considerations,
        CASE 
            WHEN LOWER(p_primary_complaint) LIKE '%chest pain%' 
                OR LOWER(p_primary_complaint) LIKE '%severe%' THEN 'High'
            WHEN LOWER(p_primary_complaint) LIKE '%chronic%' THEN 'Low'
            ELSE 'Medium'
        END AS urgency_level;
END //
DELIMITER ;

-- Procedure: Drug Interaction and Contraindication Checker
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_comprehensive_drug_interaction_check(
    IN p_patient_id INT,
    IN p_new_medicine_ids TEXT  -- Comma-separated medicine IDs
)
BEGIN
    -- Check for interactions with current medications
    SELECT 
        'Current Medication Profile' AS check_type,
        m.medicine_id,
        m.name AS medicine_name,
        m.category,
        pr.prescribed_date,
        pr.duration_days,
        DATE_ADD(pr.prescribed_date, INTERVAL pr.duration_days DAY) AS expected_end_date,
        CASE 
            WHEN DATE_ADD(pr.prescribed_date, INTERVAL pr.duration_days DAY) >= CURDATE() 
            THEN 'Active' 
            ELSE 'Completed' 
        END AS prescription_status
    FROM prescriptions pr
    JOIN medicine m ON pr.medicine_id = m.medicine_id
    WHERE pr.appointment_id IN (
        SELECT appointment_id FROM appointments WHERE patient_id = p_patient_id
    )
    AND DATE_ADD(pr.prescribed_date, INTERVAL pr.duration_days DAY) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    ORDER BY pr.prescribed_date DESC;
    
    -- Check for potential category-level interactions
    SELECT 
        'Potential Category Interactions' AS check_type,
        current_meds.category AS current_medication_category,
        new_meds.category AS new_medication_category,
        COUNT(*) AS interaction_count,
        CASE 
            WHEN current_meds.category = new_meds.category THEN 'Same category - Risk of overdose or cumulative effects'
            WHEN (current_meds.category LIKE '%Antibiotic%' AND new_meds.category LIKE '%Antacid%')
                OR (current_meds.category LIKE '%Antacid%' AND new_meds.category LIKE '%Antibiotic%')
            THEN 'Antacid-Antibiotic interaction - Space dosing'
            WHEN (current_meds.category LIKE '%Anti%' AND new_meds.category LIKE '%Anti%')
            THEN 'Multiple anti-inflammatory agents - Monitor GI effects'
            ELSE 'Possible interaction - Pharmacist review recommended'
        END AS interaction_warning,
        'Consult pharmacist or physician before combining' AS recommendation
    FROM (
        SELECT DISTINCT m.category
        FROM prescriptions pr
        JOIN medicine m ON pr.medicine_id = m.medicine_id
        WHERE pr.appointment_id IN (
            SELECT appointment_id FROM appointments WHERE patient_id = p_patient_id
        )
        AND DATE_ADD(pr.prescribed_date, INTERVAL pr.duration_days DAY) >= CURDATE()
    ) current_meds
    CROSS JOIN (
        SELECT category FROM medicine 
        WHERE FIND_IN_SET(medicine_id, p_new_medicine_ids)
    ) new_meds;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 6: ADVANCED OPERATIONAL INTELLIGENCE
-- ============================================================================

-- Procedure: Real-time Operational Dashboard
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_realtime_operational_dashboard()
BEGIN
    -- Today's operational metrics
    SELECT 
        'Todays Operations' AS metric_category,
        COUNT(CASE WHEN status = 'Scheduled' THEN 1 END) AS scheduled_appointments,
        COUNT(CASE WHEN status = 'Completed' THEN 1 END) AS completed_appointments,
        COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) AS cancelled_appointments,
        COUNT(CASE WHEN status = 'NoShow' THEN 1 END) AS no_shows,
        ROUND(
            COUNT(CASE WHEN status = 'Completed' THEN 1 END) * 100.0 / 
            NULLIF(COUNT(*), 0),
            2
        ) AS completion_rate_percent,
        COUNT(DISTINCT doctor_id) AS active_doctors_today,
        COUNT(DISTINCT patient_id) AS unique_patients_today
    FROM appointments
    WHERE DATE(appointment_date) = CURDATE();
    
    -- Current hour statistics
    SELECT 
        'Current Hour Activity' AS metric_category,
        COUNT(*) AS appointments_this_hour,
        COUNT(DISTINCT doctor_id) AS doctors_seeing_patients,
        ROUND(AVG(TIMESTAMPDIFF(MINUTE, created_at, appointment_date)), 0) AS avg_booking_lead_minutes
    FROM appointments
    WHERE DATE(appointment_date) = CURDATE()
    AND HOUR(appointment_date) = HOUR(NOW());
    
    -- Department workload today
    SELECT 
        'Department Workload Today' AS metric_category,
        dept.name AS department,
        COUNT(DISTINCT d.doctor_id) AS doctors_on_duty,
        COUNT(a.appointment_id) AS appointments_today,
        COUNT(CASE WHEN a.status = 'Scheduled' THEN 1 END) AS pending,
        COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) AS completed,
        ROUND(
            COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0),
            2
        ) AS appointments_per_doctor,
        CASE 
            WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 10 THEN 'High Load'
            WHEN COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0) > 5 THEN 'Moderate Load'
            ELSE 'Light Load'
        END AS workload_status
    FROM departments dept
    JOIN doctors d ON dept.dept_id = d.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id 
        AND DATE(a.appointment_date) = CURDATE()
    GROUP BY dept.dept_id, dept.name
    ORDER BY appointments_per_doctor DESC;
    
    -- Revenue metrics today
    SELECT 
        'Revenue Metrics Today' AS metric_category,
        COUNT(i.invoice_id) AS invoices_generated,
        SUM(i.net_amount) AS total_invoiced,
        SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) AS collected_today,
        SUM(CASE WHEN i.status = 'Pending' THEN i.net_amount ELSE 0 END) AS pending_collection,
        ROUND(
            SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) * 100.0 / 
            NULLIF(SUM(i.net_amount), 0),
            2
        ) AS collection_rate_percent
    FROM invoices i
    WHERE DATE(i.generated_at) = CURDATE();
    
    -- Resource utilization today
    SELECT 
        'Resource Utilization Today' AS metric_category,
        COUNT(DISTINCT rb.room_id) AS rooms_in_use,
        COALESCE(SUM(rb.hours), 0) AS total_room_hours,
        COUNT(DISTINCT pt.test_id) AS tests_conducted,
        COUNT(DISTINCT ps.medicine_id) AS medicines_dispensed,
        COALESCE(SUM(ps.total_price), 0) AS pharmacy_revenue_today
    FROM room_bookings rb
    LEFT JOIN patient_tests pt ON DATE(pt.prescribed_date) = CURDATE()
    LEFT JOIN pharmacy_sales ps ON DATE(ps.sale_date) = CURDATE()
    WHERE DATE(rb.booking_date) = CURDATE();
END //
DELIMITER ;

-- Procedure: Capacity Planning and Forecasting
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_capacity_planning_forecast(
    IN p_planning_horizon_months INT
)
BEGIN
    DECLARE v_current_capacity INT;
    DECLARE v_avg_monthly_growth DECIMAL(10,4);
    DECLARE v_projected_demand INT;
    
    -- Calculate current capacity
    SELECT COUNT(*) * 20 INTO v_current_capacity  -- Assuming 20 appointments per doctor per month
    FROM doctors WHERE EXISTS (
        SELECT 1 FROM users WHERE users.user_id = doctors.user_id AND users.is_active = TRUE
    );
    
    -- Calculate growth rate
    WITH MonthlyAppointments AS (
        SELECT 
            DATE_FORMAT(appointment_date, '%Y-%m') AS month_key,
            COUNT(*) AS monthly_count
        FROM appointments
        WHERE appointment_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
        GROUP BY month_key
    ),
    GrowthRates AS (
        SELECT 
            (monthly_count - LAG(monthly_count) OVER (ORDER BY month_key)) / 
            NULLIF(LAG(monthly_count) OVER (ORDER BY month_key), 0) AS growth_rate
        FROM MonthlyAppointments
    )
    SELECT AVG(growth_rate) INTO v_avg_monthly_growth
    FROM GrowthRates WHERE growth_rate IS NOT NULL;
    
    SET v_avg_monthly_growth = COALESCE(v_avg_monthly_growth, 0.05);  -- Default 5% growth
    
    -- Calculate projected demand
    SELECT COUNT(*) INTO v_projected_demand
    FROM appointments
    WHERE DATE_FORMAT(appointment_date, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m');
    
    -- Generate forecast
    SELECT 
        'Capacity Planning Forecast' AS report_type,
        v_current_capacity AS current_monthly_capacity,
        v_projected_demand AS current_monthly_demand,
        ROUND(v_current_capacity - v_projected_demand, 0) AS current_surplus_deficit,
        ROUND(v_avg_monthly_growth * 100, 2) AS monthly_growth_rate_percent,
        ROUND(v_projected_demand * POW(1 + v_avg_monthly_growth, p_planning_horizon_months), 0) AS forecasted_demand,
        v_current_capacity AS forecasted_capacity_if_unchanged,
        ROUND(
            v_projected_demand * POW(1 + v_avg_monthly_growth, p_planning_horizon_months) - v_current_capacity,
            0
        ) AS projected_capacity_gap,
        CASE 
            WHEN v_projected_demand * POW(1 + v_avg_monthly_growth, p_planning_horizon_months) > v_current_capacity * 1.2
            THEN CONCAT('Hire ', CEILING((v_projected_demand * POW(1 + v_avg_monthly_growth, p_planning_horizon_months) - v_current_capacity) / 20), ' additional doctors')
            WHEN v_projected_demand * POW(1 + v_avg_monthly_growth, p_planning_horizon_months) > v_current_capacity
            THEN 'Extend operating hours or add part-time staff'
            ELSE 'Current capacity sufficient'
        END AS capacity_recommendation;
    
    -- Month-by-month forecast
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_monthly_forecast (
        forecast_month INT,
        forecast_date DATE,
        projected_appointments INT,
        required_capacity INT,
        gap INT
    );
    
    TRUNCATE TABLE tmp_monthly_forecast;
    
    SET @month := 1;
    WHILE @month <= p_planning_horizon_months DO
        INSERT INTO tmp_monthly_forecast
        SELECT 
            @month,
            DATE_ADD(LAST_DAY(CURDATE()), INTERVAL @month MONTH),
            ROUND(v_projected_demand * POW(1 + v_avg_monthly_growth, @month), 0),
            v_current_capacity,
            ROUND(v_projected_demand * POW(1 + v_avg_monthly_growth, @month), 0) - v_current_capacity;
        SET @month := @month + 1;
    END WHILE;
    
    SELECT * FROM tmp_monthly_forecast ORDER BY forecast_month;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_monthly_forecast;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 7: ADVANCED COMPLIANCE AND REGULATORY REPORTING
-- ============================================================================

-- Procedure: HIPAA Compliance Audit Trail
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_hipaa_compliance_audit(
    IN p_audit_period_days INT
)
BEGIN
    -- Access log analysis
    SELECT 
        'Patient Record Access Audit' AS audit_category,
        al.table_name,
        al.action_type,
        COUNT(*) AS access_count,
        COUNT(DISTINCT al.performed_by) AS unique_users_accessing,
        COUNT(DISTINCT al.record_id) AS unique_records_accessed,
        MIN(al.performed_at) AS first_access,
        MAX(al.performed_at) AS last_access
    FROM audit_logs al
    WHERE al.performed_at >= DATE_SUB(CURDATE(), INTERVAL p_audit_period_days DAY)
    AND al.table_name IN ('patients', 'medical_records', 'prescriptions', 'patient_tests')
    GROUP BY al.table_name, al.action_type
    ORDER BY access_count DESC;
    
    -- Suspicious access patterns
    SELECT 
        'Suspicious Access Patterns' AS audit_category,
        al.performed_by AS user_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS user_name,
        u.role,
        COUNT(DISTINCT DATE(al.performed_at)) AS days_active,
        COUNT(*) AS total_accesses,
        COUNT(DISTINCT al.record_id) AS unique_records,
        ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT DATE(al.performed_at)), 0), 2) AS avg_accesses_per_day,
        CASE 
            WHEN COUNT(*) / NULLIF(COUNT(DISTINCT DATE(al.performed_at)), 0) > 100 THEN 'High Risk - Unusual Activity'
            WHEN COUNT(*) / NULLIF(COUNT(DISTINCT DATE(al.performed_at)), 0) > 50 THEN 'Medium Risk - Monitor'
            ELSE 'Normal Activity'
        END AS risk_level
    FROM audit_logs al
    JOIN users u ON al.performed_by = u.user_id
    JOIN profiles pr ON u.user_id = pr.user_id
    WHERE al.performed_at >= DATE_SUB(CURDATE(), INTERVAL p_audit_period_days DAY)
    GROUP BY al.performed_by, pr.first_name, pr.last_name, u.role
    HAVING avg_accesses_per_day > 30
    ORDER BY avg_accesses_per_day DESC;
    
    -- Data modification audit
    SELECT 
        'Data Modification Audit' AS audit_category,
        al.table_name,
        al.action_type,
        CONCAT(pr.first_name, ' ', pr.last_name) AS modified_by,
        u.role,
        COUNT(*) AS modification_count,
        MAX(al.performed_at) AS last_modification
    FROM audit_logs al
    JOIN users u ON al.performed_by = u.user_id
    JOIN profiles pr ON u.user_id = pr.user_id
    WHERE al.performed_at >= DATE_SUB(CURDATE(), INTERVAL p_audit_period_days DAY)
    AND al.action_type IN ('UPDATE', 'DELETE')
    GROUP BY al.table_name, al.action_type, pr.first_name, pr.last_name, u.role
    ORDER BY modification_count DESC;
END //
DELIMITER ;

-- Procedure: Regulatory Reporting Generator
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_generate_regulatory_reports(
    IN p_report_type VARCHAR(50),  -- 'monthly', 'quarterly', 'annual'
    IN p_report_date DATE
)
BEGIN
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;
    
    -- Determine reporting period
    IF p_report_type = 'monthly' THEN
        SET v_start_date = DATE_FORMAT(p_report_date, '%Y-%m-01');
        SET v_end_date = LAST_DAY(p_report_date);
    ELSEIF p_report_type = 'quarterly' THEN
        SET v_start_date = DATE_FORMAT(p_report_date - INTERVAL (MONTH(p_report_date) - 1) % 3 MONTH, '%Y-%m-01');
        SET v_end_date = LAST_DAY(v_start_date + INTERVAL 2 MONTH);
    ELSE  -- annual
        SET v_start_date = DATE_FORMAT(p_report_date, '%Y-01-01');
        SET v_end_date = DATE_FORMAT(p_report_date, '%Y-12-31');
    END IF;
    
    -- Patient volume statistics
    SELECT 
        'Patient Volume Statistics' AS report_section,
        COUNT(DISTINCT p.patient_id) AS total_registered_patients,
        COUNT(DISTINCT CASE WHEN a.appointment_date BETWEEN v_start_date AND v_end_date 
            THEN a.patient_id END) AS active_patients_in_period,
        COUNT(DISTINCT CASE WHEN u.created_at BETWEEN v_start_date AND v_end_date 
            THEN p.patient_id END) AS new_registrations,
        COUNT(a.appointment_id) AS total_appointments,
        COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) AS completed_visits,
        ROUND(AVG(TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE())), 1) AS avg_patient_age
    FROM patients p
    JOIN users u ON p.user_id = u.user_id
    JOIN profiles pr ON p.user_id = pr.user_id
    LEFT JOIN appointments a ON p.patient_id = a.patient_id 
        AND a.appointment_date BETWEEN v_start_date AND v_end_date;
    
    -- Service utilization
    SELECT 
        'Service Utilization' AS report_section,
        dept.name AS department,
        COUNT(a.appointment_id) AS appointments,
        COUNT(DISTINCT a.patient_id) AS unique_patients,
        SUM(i.net_amount) AS revenue_generated,
        COUNT(DISTINCT d.doctor_id) AS active_providers
    FROM departments dept
    LEFT JOIN doctors d ON dept.dept_id = d.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id 
        AND a.appointment_date BETWEEN v_start_date AND v_end_date
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    GROUP BY dept.dept_id, dept.name
    ORDER BY appointments DESC;
    
    -- Financial summary
    SELECT 
        'Financial Summary' AS report_section,
        COUNT(i.invoice_id) AS total_invoices,
        SUM(i.total_amount) AS gross_charges,
        SUM(i.discount_amount) AS total_discounts,
        SUM(i.net_amount) AS net_charges,
        SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) AS collections,
        SUM(CASE WHEN i.status IN ('Pending', 'Overdue') THEN i.net_amount ELSE 0 END) AS outstanding,
        ROUND(
            SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) * 100.0 / 
            NULLIF(SUM(i.net_amount), 0),
            2
        ) AS collection_rate_percent
    FROM invoices i
    WHERE i.generated_at BETWEEN v_start_date AND v_end_date;
    
    -- Quality metrics
    SELECT 
        'Quality Metrics' AS report_section,
        COUNT(DISTINCT a.appointment_id) AS total_encounters,
        COUNT(DISTINCT mr.record_id) AS documented_encounters,
        ROUND(
            COUNT(DISTINCT mr.record_id) * 100.0 / NULLIF(COUNT(DISTINCT a.appointment_id), 0),
            2
        ) AS documentation_rate,
        COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) AS cancellations,
        COUNT(CASE WHEN a.status = 'NoShow' THEN 1 END) AS no_shows,
        ROUND(
            (COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) + 
             COUNT(CASE WHEN a.status = 'NoShow' THEN 1 END)) * 100.0 / 
            NULLIF(COUNT(*), 0),
            2
        ) AS missed_appointment_rate
    FROM appointments a
    LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
    WHERE a.appointment_date BETWEEN v_start_date AND v_end_date;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 8: ADVANCED BUSINESS INTELLIGENCE AND ANALYTICS
-- ============================================================================

-- Procedure: Competitive Analysis and Benchmarking
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_competitive_benchmarking()
BEGIN
    -- Internal performance benchmarks
    SELECT 
        'Internal Performance Benchmarks' AS benchmark_category,
        'Patient Satisfaction Proxy' AS metric_name,
        ROUND(
            COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0 / 
            NULLIF(COUNT(*), 0),
            2
        ) AS current_value,
        85.00 AS industry_benchmark,
        CASE 
            WHEN ROUND(
                COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0 / 
                NULLIF(COUNT(*), 0), 2
            ) >= 85.00 THEN 'Above Benchmark'
            ELSE 'Below Benchmark'
        END AS performance_vs_benchmark
    FROM appointments a
    WHERE a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    
    UNION ALL
    
    SELECT 
        'Internal Performance Benchmarks',
        'Revenue per Patient Visit',
        ROUND(AVG(i.net_amount), 2),
        1500.00,
        CASE 
            WHEN ROUND(AVG(i.net_amount), 2) >= 1500.00 THEN 'Above Benchmark'
            ELSE 'Below Benchmark'
        END
    FROM invoices i
    WHERE i.generated_at >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    AND i.status = 'Paid'
    
    UNION ALL
    
    SELECT 
        'Internal Performance Benchmarks',
        'Doctor Utilization Rate %',
        ROUND(
            COUNT(a.appointment_id) / NULLIF(
                (SELECT COUNT(*) * 90 * 8 FROM doctors 
                 WHERE EXISTS (SELECT 1 FROM users u WHERE u.user_id = doctors.user_id AND u.is_active = TRUE)),
                0
            ) * 100,
            2
        ),
        70.00,
        CASE 
            WHEN ROUND(
                COUNT(a.appointment_id) / NULLIF(
                    (SELECT COUNT(*) * 90 * 8 FROM doctors 
                     WHERE EXISTS (SELECT 1 FROM users u WHERE u.user_id = doctors.user_id AND u.is_active = TRUE)),
                    0
                ) * 100, 2
            ) >= 70.00 THEN 'Above Benchmark'
            ELSE 'Below Benchmark'
        END
    FROM appointments a
    WHERE a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY);
    
    -- Department performance comparison
    SELECT 
        'Department Performance Comparison' AS analysis_type,
        dept.name AS department,
        COUNT(a.appointment_id) AS appointment_volume,
        SUM(i.net_amount) AS revenue,
        ROUND(AVG(i.net_amount), 2) AS avg_revenue_per_visit,
        COUNT(DISTINCT a.patient_id) AS unique_patients,
        COUNT(DISTINCT d.doctor_id) AS providers,
        ROUND(
            COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0),
            2
        ) AS appointments_per_provider,
        RANK() OVER (ORDER BY SUM(i.net_amount) DESC) AS revenue_rank,
        RANK() OVER (ORDER BY COUNT(a.appointment_id) DESC) AS volume_rank
    FROM departments dept
    JOIN doctors d ON dept.dept_id = d.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
        AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    GROUP BY dept.dept_id, dept.name
    ORDER BY revenue DESC;
END //
DELIMITER ;

-- Procedure: Market Basket Analysis for Services
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_service_market_basket_analysis()
BEGIN
    -- Analyze which services are frequently used together
    SELECT 
        'Service Bundling Opportunities' AS analysis_type,
        dept1.name AS primary_service,
        dept2.name AS frequently_paired_service,
        COUNT(DISTINCT a1.patient_id) AS patients_using_both,
        ROUND(AVG(DATEDIFF(a2.appointment_date, a1.appointment_date)), 1) AS avg_days_between_services,
        SUM(i1.net_amount + i2.net_amount) AS combined_revenue,
        ROUND(AVG(i1.net_amount + i2.net_amount), 2) AS avg_combined_invoice,
        CASE 
            WHEN AVG(DATEDIFF(a2.appointment_date, a1.appointment_date)) <= 7 THEN 'Strong Association - Bundle Opportunity'
            WHEN AVG(DATEDIFF(a2.appointment_date, a1.appointment_date)) <= 30 THEN 'Moderate Association - Package Deal'
            ELSE 'Weak Association'
        END AS bundling_recommendation
    FROM appointments a1
    JOIN appointments a2 ON a1.patient_id = a2.patient_id AND a2.appointment_date > a1.appointment_date
    JOIN doctors d1 ON a1.doctor_id = d1.doctor_id
    JOIN doctors d2 ON a2.doctor_id = d2.doctor_id
    JOIN departments dept1 ON d1.dept_id = dept1.dept_id
    JOIN departments dept2 ON d2.dept_id = dept2.dept_id
    LEFT JOIN invoices i1 ON a1.appointment_id = i1.appointment_id
    LEFT JOIN invoices i2 ON a2.appointment_id = i2.appointment_id
    WHERE a1.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
    AND dept1.dept_id != dept2.dept_id
    AND DATEDIFF(a2.appointment_date, a1.appointment_date) <= 90
    GROUP BY dept1.name, dept2.name
    HAVING patients_using_both >= 5
    ORDER BY patients_using_both DESC, combined_revenue DESC
    LIMIT 20;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 9: ADVANCED PREDICTIVE MAINTENANCE AND SYSTEM HEALTH
-- ============================================================================

-- Procedure: Database Performance Monitoring
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_monitor_database_performance()
BEGIN
    -- Table size analysis
    SELECT 
        'Database Storage Analysis' AS metric_category,
        table_name,
        ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb,
        table_rows AS estimated_rows,
        ROUND((data_length / 1024 / 1024), 2) AS data_size_mb,
        ROUND((index_length / 1024 / 1024), 2) AS index_size_mb,
        ROUND((index_length / NULLIF(data_length, 0) * 100), 2) AS index_to_data_ratio_percent
    FROM information_schema.tables
    WHERE table_schema = 'careconnect'
    ORDER BY (data_length + index_length) DESC
    LIMIT 20;
    
    -- Growth trend analysis
    SELECT 
        'Data Growth Trends' AS metric_category,
        'appointments' AS table_name,
        COUNT(*) AS current_row_count,
        COUNT(CASE WHEN appointment_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) AS rows_last_30_days,
        COUNT(CASE WHEN appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 END) AS rows_last_90_days,
        ROUND(
            COUNT(CASE WHEN appointment_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) / 30,
            2
        ) AS daily_growth_rate
    FROM appointments
    
    UNION ALL
    
    SELECT 
        'Data Growth Trends',
        'medical_records',
        COUNT(*),
        COUNT(CASE WHEN created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END),
        COUNT(CASE WHEN created_at >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 END),
        ROUND(
            COUNT(CASE WHEN created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) / 30,
            2
        )
    FROM medical_records
    
    UNION ALL
    
    SELECT 
        'Data Growth Trends',
        'invoices',
        COUNT(*),
        COUNT(CASE WHEN generated_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END),
        COUNT(CASE WHEN generated_at >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 END),
        ROUND(
            COUNT(CASE WHEN generated_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) / 30,
            2
        )
    FROM invoices;
END //
DELIMITER ;

-- Procedure: System Health Check and Alerts
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_system_health_check()
BEGIN
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_health_alerts (
        alert_priority VARCHAR(20),
        alert_category VARCHAR(100),
        alert_message TEXT,
        affected_count INT,
        recommended_action TEXT
    );
    
    TRUNCATE TABLE tmp_health_alerts;
    
    -- Check for appointments without medical records
    INSERT INTO tmp_health_alerts
    SELECT 
        'High' AS alert_priority,
        'Missing Medical Records' AS alert_category,
        CONCAT('Found ', COUNT(*), ' completed appointments without medical records') AS alert_message,
        COUNT(*) AS affected_count,
        'Create medical records immediately to maintain compliance' AS recommended_action
    FROM appointments a
    LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
    WHERE a.status = 'Completed'
    AND mr.record_id IS NULL
    AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    HAVING affected_count > 0;
    
    -- Check for old pending invoices
    INSERT INTO tmp_health_alerts
    SELECT 
        'Medium',
        'Aging Pending Invoices',
        CONCAT('Found ', COUNT(*), ' invoices pending over 60 days'),
        COUNT(*),
        'Initiate collection procedures'
    FROM invoices
    WHERE status = 'Pending'
    AND DATEDIFF(CURDATE(), generated_at) > 60
    HAVING affected_count > 0;
    
    -- Check for inactive doctors with scheduled appointments
    INSERT INTO tmp_health_alerts
    SELECT 
        'High',
        'Inactive Doctor Appointments',
        CONCAT('Found ', COUNT(*), ' future appointments with inactive doctors'),
        COUNT(*),
        'Reassign appointments to active doctors'
    FROM appointments a
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN users u ON d.user_id = u.user_id
    WHERE a.appointment_date > CURDATE()
    AND u.is_active = FALSE
    HAVING affected_count > 0;
    
    -- Check for low medicine stock
    INSERT INTO tmp_health_alerts
    SELECT 
        'Medium',
        'Low Medicine Inventory',
        CONCAT('Found ', COUNT(*), ' medicines with critically low stock'),
        COUNT(*),
        'Reorder medicines immediately'
    FROM medicine
    WHERE quantity < 10
    HAVING affected_count > 0;
    
    -- Return all alerts
    SELECT * FROM tmp_health_alerts
    ORDER BY 
        CASE alert_priority
            WHEN 'Critical' THEN 1
            WHEN 'High' THEN 2
            WHEN 'Medium' THEN 3
            ELSE 4
        END,
        affected_count DESC;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_health_alerts;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 10: ADVANCED MACHINE LEARNING PREPARATION AND DATA SCIENCE
-- ============================================================================

-- Procedure: Prepare Dataset for ML Model Training
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_prepare_ml_training_dataset(
    IN p_dataset_type VARCHAR(50)  -- 'churn_prediction', 'revenue_forecast', 'disease_prediction'
)
BEGIN
    IF p_dataset_type = 'churn_prediction' THEN
        -- Prepare patient churn prediction dataset
        SELECT 
            p.patient_id,
            TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) AS age,
            CASE pr.gender WHEN 'Male' THEN 1 WHEN 'Female' THEN 0 ELSE NULL END AS gender_encoded,
            COUNT(a.appointment_id) AS total_visits,
            COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) AS completed_visits,
            COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) AS cancelled_visits,
            ROUND(
                COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0 / 
                NULLIF(COUNT(a.appointment_id), 0),
                2
            ) AS completion_rate,
            COUNT(DISTINCT a.doctor_id) AS unique_doctors_seen,
            COALESCE(SUM(i.net_amount), 0) AS total_lifetime_value,
            COALESCE(AVG(i.net_amount), 0) AS avg_invoice_amount,
            COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) AS days_since_last_visit,
            COALESCE(
                DATEDIFF(MAX(a.appointment_date), MIN(a.appointment_date)) / 
                NULLIF(COUNT(a.appointment_id) - 1, 0),
                0
            ) AS avg_days_between_visits,
            CASE WHEN p.insurance_provider IS NOT NULL THEN 1 ELSE 0 END AS has_insurance,
            -- Target variable: churned if no visit in last 180 days
            CASE 
                WHEN COALESCE(DATEDIFF(CURDATE(), MAX(a.appointment_date)), 999) > 180 THEN 1 
                ELSE 0 
            END AS churned_label
        FROM patients p
        JOIN profiles pr ON p.user_id = pr.user_id
        LEFT JOIN appointments a ON p.patient_id = a.patient_id
        LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
        WHERE pr.date_of_birth IS NOT NULL
        GROUP BY p.patient_id, pr.date_of_birth, pr.gender, p.insurance_provider;
        
    ELSEIF p_dataset_type = 'revenue_forecast' THEN
        -- Prepare revenue forecasting dataset
        SELECT 
            DATE_FORMAT(generated_at, '%Y-%m') AS month_key,
            YEAR(generated_at) AS year,
            MONTH(generated_at) AS month,
            COUNT(*) AS invoice_count,
            SUM(net_amount) AS monthly_revenue,
            AVG(net_amount) AS avg_invoice_amount,
            COUNT(DISTINCT appointment_id) AS unique_appointments,
            -- Lagged features
            LAG(SUM(net_amount), 1) OVER (ORDER BY DATE_FORMAT(generated_at, '%Y-%m')) AS prev_month_revenue,
            LAG(SUM(net_amount), 3) OVER (ORDER BY DATE_FORMAT(generated_at, '%Y-%m')) AS three_months_ago_revenue,
            LAG(SUM(net_amount), 12) OVER (ORDER BY DATE_FORMAT(generated_at, '%Y-%m')) AS same_month_last_year_revenue
        FROM invoices
        WHERE status = 'Paid'
        GROUP BY month_key, YEAR(generated_at), MONTH(generated_at)
        ORDER BY month_key;
        
    ELSEIF p_dataset_type = 'disease_prediction' THEN
        -- Prepare disease prediction dataset
        SELECT 
            a.patient_id,
            TIMESTAMPDIFF(YEAR, pr.date_of_birth, a.appointment_date) AS age_at_diagnosis,
            pr.gender,
            p.blood_group,
            mr.diagnosis,
            MONTH(a.appointment_date) AS diagnosis_month,
            QUARTER(a.appointment_date) AS diagnosis_quarter,
            -- Historical features
            (SELECT COUNT(*) FROM appointments a2 
             WHERE a2.patient_id = a.patient_id 
             AND a2.appointment_date < a.appointment_date) AS previous_visits,
            (SELECT COUNT(DISTINCT mr2.diagnosis) 
             FROM medical_records mr2 
             JOIN appointments a2 ON mr2.appointment_id = a2.appointment_id
             WHERE a2.patient_id = a.patient_id 
             AND a2.appointment_date < a.appointment_date) AS previous_unique_diagnoses
        FROM medical_records mr
        JOIN appointments a ON mr.appointment_id = a.appointment_id
        JOIN patients p ON a.patient_id = p.patient_id
        JOIN profiles pr ON p.user_id = pr.user_id
        WHERE mr.diagnosis IS NOT NULL
        AND pr.date_of_birth IS NOT NULL;
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- END OF EXTENDED ADVANCED FEATURES
-- All procedures above are non-intrusive utilities that can be called separately
-- ============================================================================


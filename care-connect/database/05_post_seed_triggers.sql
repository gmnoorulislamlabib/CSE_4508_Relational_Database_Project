USE careconnect;

-- This trigger is applied AFTER seeding to avoid conflict with manually seeded historical invoices.

DELIMITER //
CREATE TRIGGER trg_create_test_invoice
AFTER INSERT ON patient_tests
FOR EACH ROW
BEGIN
    DECLARE test_cost DECIMAL(10, 2);
    
    -- Only create invoice if payment is PAID
    IF NEW.payment_status = 'PAID' THEN
        -- Get test cost
        SELECT cost INTO test_cost FROM medical_tests WHERE test_id = NEW.test_id;
        
        -- Create invoice
        INSERT INTO invoices (test_record_id, total_amount, discount_amount, net_amount, status, generated_at)
        VALUES (NEW.record_id, test_cost, 0.00, test_cost, 'Paid', NOW());
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- EXTENDED UTILITY LOGIC AND HELPER PROCEDURES (NON-INTRUSIVE)
-- These are utility functions and procedures that can be called separately
-- They DO NOT affect the main trigger logic above
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SECTION 1: ADVANCED ANALYTICS STORED PROCEDURES
-- ----------------------------------------------------------------------------

-- Procedure: Calculate Patient Health Risk Score
-- This calculates a comprehensive health risk score based on multiple factors
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_calculate_patient_health_risk_score(
    IN p_patient_id INT,
    OUT risk_score DECIMAL(5,2),
    OUT risk_category VARCHAR(50)
)
BEGIN
    DECLARE visit_count INT DEFAULT 0;
    DECLARE emergency_visits INT DEFAULT 0;
    DECLARE chronic_conditions INT DEFAULT 0;
    DECLARE missed_appointments INT DEFAULT 0;
    DECLARE age_years INT DEFAULT 0;
    DECLARE bmi DECIMAL(5,2) DEFAULT 0;
    DECLARE last_visit_days INT DEFAULT 0;
    DECLARE prescription_count INT DEFAULT 0;
    DECLARE lab_abnormal_count INT DEFAULT 0;
    DECLARE surgery_count INT DEFAULT 0;
    
    -- Calculate age
    SELECT TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE())
    INTO age_years
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.user_id
    WHERE p.patient_id = p_patient_id;
    
    -- Count total visits
    SELECT COUNT(*) INTO visit_count
    FROM appointments
    WHERE patient_id = p_patient_id AND status = 'Completed';
    
    -- Count emergency/urgent visits (assuming reason contains 'emergency' or 'urgent')
    SELECT COUNT(*) INTO emergency_visits
    FROM appointments
    WHERE patient_id = p_patient_id 
    AND (LOWER(reason) LIKE '%emergency%' OR LOWER(reason) LIKE '%urgent%');
    
    -- Count chronic conditions from medical history
    SELECT COUNT(*) INTO chronic_conditions
    FROM medical_records
    WHERE appointment_id IN (
        SELECT appointment_id FROM appointments WHERE patient_id = p_patient_id
    )
    AND (
        LOWER(diagnosis) LIKE '%diabetes%' OR
        LOWER(diagnosis) LIKE '%hypertension%' OR
        LOWER(diagnosis) LIKE '%heart%' OR
        LOWER(diagnosis) LIKE '%cancer%' OR
        LOWER(diagnosis) LIKE '%chronic%'
    );
    
    -- Count missed/cancelled appointments
    SELECT COUNT(*) INTO missed_appointments
    FROM appointments
    WHERE patient_id = p_patient_id 
    AND status = 'Cancelled';
    
    -- Days since last visit
    SELECT COALESCE(DATEDIFF(CURDATE(), MAX(appointment_date)), 365)
    INTO last_visit_days
    FROM appointments
    WHERE patient_id = p_patient_id AND status = 'Completed';
    
    -- Count prescriptions
    SELECT COUNT(*) INTO prescription_count
    FROM prescriptions
    WHERE appointment_id IN (
        SELECT appointment_id FROM appointments WHERE patient_id = p_patient_id
    );
    
    -- Calculate risk score (0-100 scale)
    SET risk_score = 0;
    
    -- Age factor (0-20 points)
    IF age_years < 18 THEN
        SET risk_score = risk_score + 2;
    ELSEIF age_years BETWEEN 18 AND 35 THEN
        SET risk_score = risk_score + 5;
    ELSEIF age_years BETWEEN 36 AND 55 THEN
        SET risk_score = risk_score + 10;
    ELSEIF age_years BETWEEN 56 AND 70 THEN
        SET risk_score = risk_score + 15;
    ELSE
        SET risk_score = risk_score + 20;
    END IF;
    
    -- Visit frequency factor (0-15 points)
    IF visit_count = 0 THEN
        SET risk_score = risk_score + 15;
    ELSEIF visit_count BETWEEN 1 AND 3 THEN
        SET risk_score = risk_score + 10;
    ELSEIF visit_count BETWEEN 4 AND 10 THEN
        SET risk_score = risk_score + 5;
    ELSE
        SET risk_score = risk_score + 2;
    END IF;
    
    -- Emergency visits factor (0-20 points)
    SET risk_score = risk_score + LEAST(emergency_visits * 5, 20);
    
    -- Chronic conditions factor (0-25 points)
    SET risk_score = risk_score + LEAST(chronic_conditions * 8, 25);
    
    -- Missed appointments factor (0-10 points)
    SET risk_score = risk_score + LEAST(missed_appointments * 2, 10);
    
    -- Last visit recency (0-10 points)
    IF last_visit_days > 365 THEN
        SET risk_score = risk_score + 10;
    ELSEIF last_visit_days > 180 THEN
        SET risk_score = risk_score + 5;
    ELSEIF last_visit_days > 90 THEN
        SET risk_score = risk_score + 2;
    END IF;
    
    -- Determine risk category
    IF risk_score >= 75 THEN
        SET risk_category = 'Critical Risk';
    ELSEIF risk_score >= 60 THEN
        SET risk_category = 'High Risk';
    ELSEIF risk_score >= 40 THEN
        SET risk_category = 'Moderate Risk';
    ELSEIF risk_score >= 20 THEN
        SET risk_category = 'Low Risk';
    ELSE
        SET risk_category = 'Minimal Risk';
    END IF;
END //
DELIMITER ;

-- Procedure: Generate Comprehensive Patient Health Report
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_generate_patient_health_report(
    IN p_patient_id INT
)
BEGIN
    DECLARE v_patient_name VARCHAR(200);
    DECLARE v_age INT;
    DECLARE v_gender VARCHAR(20);
    DECLARE v_blood_group VARCHAR(10);
    DECLARE v_risk_score DECIMAL(5,2);
    DECLARE v_risk_category VARCHAR(50);
    
    -- Get patient demographics
    SELECT 
        CONCAT(pr.first_name, ' ', pr.last_name),
        TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()),
        pr.gender,
        p.blood_group
    INTO v_patient_name, v_age, v_gender, v_blood_group
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.user_id
    WHERE p.patient_id = p_patient_id;
    
    -- Calculate risk score
    CALL sp_calculate_patient_health_risk_score(p_patient_id, v_risk_score, v_risk_category);
    
    -- Return comprehensive report
    SELECT 
        'PATIENT HEALTH SUMMARY REPORT' AS report_title,
        v_patient_name AS patient_name,
        v_age AS age,
        v_gender AS gender,
        v_blood_group AS blood_group,
        v_risk_score AS health_risk_score,
        v_risk_category AS risk_category,
        NOW() AS report_generated_at;
    
    -- Appointment history summary
    SELECT 
        'APPOINTMENT HISTORY' AS section_title,
        COUNT(*) AS total_appointments,
        COUNT(CASE WHEN status = 'Completed' THEN 1 END) AS completed,
        COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) AS cancelled,
        COUNT(CASE WHEN status = 'Scheduled' THEN 1 END) AS scheduled,
        MIN(appointment_date) AS first_visit,
        MAX(appointment_date) AS last_visit
    FROM appointments
    WHERE patient_id = p_patient_id;
    
    -- Department visit distribution
    SELECT 
        'DEPARTMENT VISITS' AS section_title,
        dept.name AS department,
        COUNT(*) AS visit_count,
        ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM appointments WHERE patient_id = p_patient_id), 2) AS percentage
    FROM appointments a
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    WHERE a.patient_id = p_patient_id
    GROUP BY dept.dept_id, dept.name
    ORDER BY visit_count DESC;
    
    -- Financial summary
    SELECT 
        'FINANCIAL SUMMARY' AS section_title,
        COUNT(DISTINCT i.invoice_id) AS total_invoices,
        COALESCE(SUM(i.net_amount), 0) AS total_amount_billed,
        COALESCE(SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END), 0) AS total_paid,
        COALESCE(SUM(CASE WHEN i.status = 'Pending' THEN i.net_amount ELSE 0 END), 0) AS outstanding_balance
    FROM appointments a
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
    WHERE a.patient_id = p_patient_id;
    
    -- Recent diagnoses
    SELECT 
        'RECENT DIAGNOSES' AS section_title,
        mr.diagnosis,
        mr.treatment_plan,
        a.appointment_date
    FROM medical_records mr
    JOIN appointments a ON mr.appointment_id = a.appointment_id
    WHERE a.patient_id = p_patient_id
    ORDER BY a.appointment_date DESC
    LIMIT 5;
END //
DELIMITER ;

-- Procedure: Automated Department Performance Evaluation
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_evaluate_department_performance(
    IN p_dept_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE v_dept_name VARCHAR(100);
    DECLARE v_total_doctors INT;
    DECLARE v_total_appointments INT;
    DECLARE v_total_revenue DECIMAL(12,2);
    DECLARE v_avg_wait_time INT;
    DECLARE v_patient_satisfaction_proxy DECIMAL(5,2);
    DECLARE v_performance_score DECIMAL(5,2);
    DECLARE v_performance_grade VARCHAR(2);
    
    -- Get department name
    SELECT name INTO v_dept_name
    FROM departments
    WHERE dept_id = p_dept_id;
    
    -- Count active doctors
    SELECT COUNT(*) INTO v_total_doctors
    FROM doctors
    WHERE dept_id = p_dept_id;
    
    -- Count appointments in date range
    SELECT COUNT(*) INTO v_total_appointments
    FROM appointments a
    JOIN doctors d ON a.doctor_id = d.doctor_id
    WHERE d.dept_id = p_dept_id
    AND a.appointment_date BETWEEN p_start_date AND p_end_date;
    
    -- Calculate total revenue
    SELECT COALESCE(SUM(i.net_amount), 0) INTO v_total_revenue
    FROM invoices i
    JOIN appointments a ON i.appointment_id = a.appointment_id
    JOIN doctors d ON a.doctor_id = d.doctor_id
    WHERE d.dept_id = p_dept_id
    AND i.generated_at BETWEEN p_start_date AND p_end_date;
    
    -- Calculate patient satisfaction proxy (completion rate)
    SELECT 
        COALESCE(
            COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0 / 
            NULLIF(COUNT(*), 0),
            0
        )
    INTO v_patient_satisfaction_proxy
    FROM appointments a
    JOIN doctors d ON a.doctor_id = d.doctor_id
    WHERE d.dept_id = p_dept_id
    AND a.appointment_date BETWEEN p_start_date AND p_end_date;
    
    -- Calculate performance score (0-100)
    SET v_performance_score = 0;
    
    -- Appointments per doctor factor (30 points max)
    IF v_total_doctors > 0 THEN
        SET v_performance_score = v_performance_score + 
            LEAST((v_total_appointments / v_total_doctors) / 10 * 30, 30);
    END IF;
    
    -- Revenue factor (40 points max)
    IF v_total_revenue > 0 THEN
        SET v_performance_score = v_performance_score + 
            LEAST(v_total_revenue / 1000, 40);
    END IF;
    
    -- Patient satisfaction factor (30 points max)
    SET v_performance_score = v_performance_score + 
        (v_patient_satisfaction_proxy * 0.3);
    
    -- Determine grade
    IF v_performance_score >= 90 THEN
        SET v_performance_grade = 'A+';
    ELSEIF v_performance_score >= 85 THEN
        SET v_performance_grade = 'A';
    ELSEIF v_performance_score >= 80 THEN
        SET v_performance_grade = 'A-';
    ELSEIF v_performance_score >= 75 THEN
        SET v_performance_grade = 'B+';
    ELSEIF v_performance_score >= 70 THEN
        SET v_performance_grade = 'B';
    ELSEIF v_performance_score >= 65 THEN
        SET v_performance_grade = 'B-';
    ELSEIF v_performance_score >= 60 THEN
        SET v_performance_grade = 'C+';
    ELSEIF v_performance_score >= 55 THEN
        SET v_performance_grade = 'C';
    ELSE
        SET v_performance_grade = 'D';
    END IF;
    
    -- Return performance report
    SELECT 
        v_dept_name AS department_name,
        p_start_date AS evaluation_period_start,
        p_end_date AS evaluation_period_end,
        v_total_doctors AS active_doctors,
        v_total_appointments AS total_appointments,
        ROUND(v_total_appointments / NULLIF(v_total_doctors, 0), 2) AS appointments_per_doctor,
        v_total_revenue AS total_revenue_generated,
        ROUND(v_patient_satisfaction_proxy, 2) AS completion_rate_percent,
        ROUND(v_performance_score, 2) AS performance_score,
        v_performance_grade AS performance_grade,
        NOW() AS report_generated_at;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- SECTION 2: REVENUE OPTIMIZATION AND FORECASTING
-- ----------------------------------------------------------------------------

-- Procedure: Revenue Forecasting Model
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_forecast_monthly_revenue(
    IN p_forecast_months INT
)
BEGIN
    DECLARE v_avg_monthly_growth DECIMAL(10,4);
    DECLARE v_last_month_revenue DECIMAL(12,2);
    DECLARE v_forecast_month INT DEFAULT 1;
    DECLARE v_forecasted_revenue DECIMAL(12,2);
    
    -- Calculate average monthly growth rate
    WITH MonthlyRevenue AS (
        SELECT 
            DATE_FORMAT(generated_at, '%Y-%m') AS month_key,
            SUM(net_amount) AS monthly_revenue
        FROM invoices
        WHERE status = 'Paid'
        AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
        GROUP BY DATE_FORMAT(generated_at, '%Y-%m')
        ORDER BY month_key
    ),
    GrowthRates AS (
        SELECT 
            month_key,
            monthly_revenue,
            LAG(monthly_revenue) OVER (ORDER BY month_key) AS prev_month_revenue,
            (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month_key)) / 
                NULLIF(LAG(monthly_revenue) OVER (ORDER BY month_key), 0) AS growth_rate
        FROM MonthlyRevenue
    )
    SELECT AVG(growth_rate) INTO v_avg_monthly_growth
    FROM GrowthRates
    WHERE growth_rate IS NOT NULL;
    
    -- Get last month's revenue
    SELECT COALESCE(SUM(net_amount), 0) INTO v_last_month_revenue
    FROM invoices
    WHERE status = 'Paid'
    AND DATE_FORMAT(generated_at, '%Y-%m') = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 MONTH), '%Y-%m');
    
    -- Create temporary table for forecast results
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_revenue_forecast (
        forecast_month INT,
        forecast_date DATE,
        forecasted_revenue DECIMAL(12,2),
        lower_bound DECIMAL(12,2),
        upper_bound DECIMAL(12,2),
        confidence_level VARCHAR(20)
    );
    
    TRUNCATE TABLE tmp_revenue_forecast;
    
    -- Generate forecasts
    WHILE v_forecast_month <= p_forecast_months DO
        SET v_forecasted_revenue = v_last_month_revenue * POW(1 + COALESCE(v_avg_monthly_growth, 0.02), v_forecast_month);
        
        INSERT INTO tmp_revenue_forecast VALUES (
            v_forecast_month,
            DATE_ADD(LAST_DAY(CURDATE()), INTERVAL v_forecast_month MONTH),
            v_forecasted_revenue,
            v_forecasted_revenue * 0.85,  -- 15% lower bound
            v_forecasted_revenue * 1.15,  -- 15% upper bound
            '85% Confidence'
        );
        
        SET v_forecast_month = v_forecast_month + 1;
    END WHILE;
    
    -- Return forecast results
    SELECT * FROM tmp_revenue_forecast ORDER BY forecast_month;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_revenue_forecast;
END //
DELIMITER ;

-- Procedure: Identify Revenue Optimization Opportunities
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_identify_revenue_opportunities()
BEGIN
    -- Underutilized doctors
    SELECT 
        'Underutilized Doctors' AS opportunity_category,
        CONCAT(pr.first_name, ' ', pr.last_name) AS doctor_name,
        dept.name AS department,
        COUNT(a.appointment_id) AS appointments_last_30_days,
        d.consultation_fee,
        (50 - COUNT(a.appointment_id)) * d.consultation_fee AS potential_monthly_revenue_increase,
        'Increase marketing and appointment availability' AS recommendation
    FROM doctors d
    JOIN profiles pr ON d.user_id = pr.user_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id 
        AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    GROUP BY d.doctor_id, pr.first_name, pr.last_name, dept.name, d.consultation_fee
    HAVING appointments_last_30_days < 20
    ORDER BY potential_monthly_revenue_increase DESC
    LIMIT 10;
    
    -- High-value patients with long gaps
    SELECT 
        'Re-engagement Opportunity' AS opportunity_category,
        CONCAT(pr.first_name, ' ', pr.last_name) AS patient_name,
        MAX(a.appointment_date) AS last_visit_date,
        DATEDIFF(CURDATE(), MAX(a.appointment_date)) AS days_since_visit,
        COUNT(a.appointment_id) AS historical_visits,
        ROUND(AVG(i.net_amount), 2) AS avg_invoice_amount,
        ROUND(COUNT(a.appointment_id) * AVG(i.net_amount) * 0.3, 2) AS estimated_annual_value,
        'Send personalized re-engagement campaign' AS recommendation
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.user_id
    JOIN appointments a ON p.patient_id = a.patient_id
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
    GROUP BY p.patient_id, pr.first_name, pr.last_name
    HAVING days_since_visit > 90 
    AND historical_visits >= 3
    AND avg_invoice_amount > 100
    ORDER BY estimated_annual_value DESC
    LIMIT 10;
    
    -- Departments with capacity for growth
    SELECT 
        'Department Expansion' AS opportunity_category,
        dept.name AS department,
        COUNT(DISTINCT d.doctor_id) AS current_doctors,
        COUNT(a.appointment_id) AS total_appointments,
        ROUND(COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0), 2) AS appointments_per_doctor,
        SUM(i.net_amount) AS current_revenue,
        ROUND(SUM(i.net_amount) * 0.5, 2) AS potential_revenue_with_1_doctor,
        'Consider hiring additional doctor' AS recommendation
    FROM departments dept
    JOIN doctors d ON dept.dept_id = d.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id 
        AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
    GROUP BY dept.dept_id, dept.name
    HAVING appointments_per_doctor > 40
    ORDER BY potential_revenue_with_1_doctor DESC
    LIMIT 5;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- SECTION 3: PATIENT LIFECYCLE MANAGEMENT
-- ----------------------------------------------------------------------------

-- Procedure: Patient Lifecycle Stage Classification
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_classify_patient_lifecycle_stage(
    IN p_patient_id INT,
    OUT lifecycle_stage VARCHAR(50),
    OUT engagement_score DECIMAL(5,2),
    OUT recommended_action VARCHAR(255)
)
BEGIN
    DECLARE v_days_since_registration INT;
    DECLARE v_total_visits INT;
    DECLARE v_days_since_last_visit INT;
    DECLARE v_total_spent DECIMAL(10,2);
    DECLARE v_cancelled_count INT;
    DECLARE v_completed_count INT;
    
    -- Get registration age
    SELECT DATEDIFF(CURDATE(), u.created_at) INTO v_days_since_registration
    FROM patients p
    JOIN users u ON p.user_id = u.user_id
    WHERE p.patient_id = p_patient_id;
    
    -- Get visit statistics
    SELECT 
        COUNT(*) AS total_visits,
        COALESCE(DATEDIFF(CURDATE(), MAX(appointment_date)), 999) AS days_since_last,
        COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) AS cancelled,
        COUNT(CASE WHEN status = 'Completed' THEN 1 END) AS completed
    INTO v_total_visits, v_days_since_last_visit, v_cancelled_count, v_completed_count
    FROM appointments
    WHERE patient_id = p_patient_id;
    
    -- Calculate total spending
    SELECT COALESCE(SUM(i.net_amount), 0) INTO v_total_spent
    FROM appointments a
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
    WHERE a.patient_id = p_patient_id AND i.status = 'Paid';
    
    -- Calculate engagement score (0-100)
    SET engagement_score = 0;
    
    -- Visit frequency component (40 points)
    IF v_total_visits = 0 THEN
        SET engagement_score = engagement_score + 0;
    ELSEIF v_total_visits = 1 THEN
        SET engagement_score = engagement_score + 10;
    ELSEIF v_total_visits BETWEEN 2 AND 5 THEN
        SET engagement_score = engagement_score + 25;
    ELSE
        SET engagement_score = engagement_score + 40;
    END IF;
    
    -- Recency component (30 points)
    IF v_days_since_last_visit <= 30 THEN
        SET engagement_score = engagement_score + 30;
    ELSEIF v_days_since_last_visit <= 90 THEN
        SET engagement_score = engagement_score + 20;
    ELSEIF v_days_since_last_visit <= 180 THEN
        SET engagement_score = engagement_score + 10;
    ELSE
        SET engagement_score = engagement_score + 0;
    END IF;
    
    -- Completion rate component (20 points)
    IF v_total_visits > 0 THEN
        SET engagement_score = engagement_score + 
            (v_completed_count * 20.0 / v_total_visits);
    END IF;
    
    -- Monetary value component (10 points)
    IF v_total_spent >= 1000 THEN
        SET engagement_score = engagement_score + 10;
    ELSEIF v_total_spent >= 500 THEN
        SET engagement_score = engagement_score + 7;
    ELSEIF v_total_spent >= 200 THEN
        SET engagement_score = engagement_score + 4;
    END IF;
    
    -- Determine lifecycle stage and recommended action
    IF v_total_visits = 0 AND v_days_since_registration <= 30 THEN
        SET lifecycle_stage = 'New Registration';
        SET recommended_action = 'Send welcome email and schedule first appointment';
    ELSEIF v_total_visits = 1 AND v_days_since_last_visit <= 90 THEN
        SET lifecycle_stage = 'First-Time Patient';
        SET recommended_action = 'Follow up with satisfaction survey and health tips';
    ELSEIF v_total_visits >= 2 AND v_days_since_last_visit <= 60 THEN
        SET lifecycle_stage = 'Active Patient';
        SET recommended_action = 'Continue regular care, offer preventive health packages';
    ELSEIF v_total_visits >= 5 AND v_days_since_last_visit <= 30 THEN
        SET lifecycle_stage = 'Loyal Patient';
        SET recommended_action = 'Offer VIP benefits, priority scheduling, loyalty rewards';
    ELSEIF v_days_since_last_visit BETWEEN 90 AND 180 THEN
        SET lifecycle_stage = 'At Risk';
        SET recommended_action = 'Send re-engagement campaign with health reminders';
    ELSEIF v_days_since_last_visit > 180 THEN
        SET lifecycle_stage = 'Dormant';
        SET recommended_action = 'Aggressive re-engagement: special offers, personal outreach';
    ELSE
        SET lifecycle_stage = 'Inactive';
        SET recommended_action = 'Archive or final re-engagement attempt';
    END IF;
END //
DELIMITER ;

-- Procedure: Batch Update Patient Lifecycle Stages
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_batch_update_patient_lifecycles()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_patient_id INT;
    DECLARE v_lifecycle_stage VARCHAR(50);
    DECLARE v_engagement_score DECIMAL(5,2);
    DECLARE v_recommended_action VARCHAR(255);
    
    DECLARE patient_cursor CURSOR FOR 
        SELECT patient_id FROM patients WHERE EXISTS (
            SELECT 1 FROM users u WHERE u.user_id = patients.user_id AND u.is_active = TRUE
        );
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Create temporary results table
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_patient_lifecycle_summary (
        patient_id INT,
        patient_name VARCHAR(200),
        lifecycle_stage VARCHAR(50),
        engagement_score DECIMAL(5,2),
        recommended_action VARCHAR(255),
        analysis_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    TRUNCATE TABLE tmp_patient_lifecycle_summary;
    
    OPEN patient_cursor;
    
    read_loop: LOOP
        FETCH patient_cursor INTO v_patient_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Classify patient
        CALL sp_classify_patient_lifecycle_stage(
            v_patient_id, 
            v_lifecycle_stage, 
            v_engagement_score, 
            v_recommended_action
        );
        
        -- Insert into summary table
        INSERT INTO tmp_patient_lifecycle_summary 
        SELECT 
            v_patient_id,
            CONCAT(pr.first_name, ' ', pr.last_name),
            v_lifecycle_stage,
            v_engagement_score,
            v_recommended_action,
            NOW()
        FROM patients p
        JOIN profiles pr ON p.user_id = pr.user_id
        WHERE p.patient_id = v_patient_id;
    END LOOP;
    
    CLOSE patient_cursor;
    
    -- Return summary results
    SELECT 
        lifecycle_stage,
        COUNT(*) AS patient_count,
        ROUND(AVG(engagement_score), 2) AS avg_engagement_score,
        recommended_action
    FROM tmp_patient_lifecycle_summary
    GROUP BY lifecycle_stage, recommended_action
    ORDER BY patient_count DESC;
    
    -- Detailed results
    SELECT * FROM tmp_patient_lifecycle_summary
    ORDER BY engagement_score DESC;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_patient_lifecycle_summary;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- SECTION 4: INTELLIGENT SCHEDULING AND RESOURCE OPTIMIZATION
-- ----------------------------------------------------------------------------

-- Procedure: Optimal Doctor Scheduling Recommendation
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_recommend_optimal_schedule(
    IN p_dept_id INT,
    IN p_analysis_weeks INT
)
BEGIN
    -- Analyze appointment patterns by day and hour
    SELECT 
        DAYNAME(appointment_date) AS day_name,
        HOUR(appointment_date) AS hour_of_day,
        COUNT(*) AS appointment_count,
        COUNT(DISTINCT doctor_id) AS doctors_needed,
        ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT doctor_id), 0), 2) AS appointments_per_doctor,
        CASE 
            WHEN COUNT(*) >= 20 THEN 'High Demand - Add Shifts'
            WHEN COUNT(*) BETWEEN 10 AND 19 THEN 'Moderate - Current OK'
            WHEN COUNT(*) BETWEEN 5 AND 9 THEN 'Low - Reduce Capacity'
            ELSE 'Very Low - Consider Closing'
        END AS scheduling_recommendation
    FROM appointments a
    JOIN doctors d ON a.doctor_id = d.doctor_id
    WHERE d.dept_id = p_dept_id
    AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL p_analysis_weeks WEEK)
    AND a.status IN ('Completed', 'Scheduled')
    GROUP BY day_name, hour_of_day
    ORDER BY appointment_count DESC;
    
    -- Doctor workload balance analysis
    SELECT 
        CONCAT(pr.first_name, ' ', pr.last_name) AS doctor_name,
        COUNT(a.appointment_id) AS total_appointments,
        ROUND(COUNT(a.appointment_id) / p_analysis_weeks, 2) AS avg_weekly_appointments,
        COUNT(DISTINCT DATE(a.appointment_date)) AS days_worked,
        ROUND(COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT DATE(a.appointment_date)), 0), 2) AS appointments_per_day,
        CASE 
            WHEN COUNT(a.appointment_id) / p_analysis_weeks > 50 THEN 'Overloaded - Redistribute'
            WHEN COUNT(a.appointment_id) / p_analysis_weeks BETWEEN 30 AND 50 THEN 'Optimal Load'
            WHEN COUNT(a.appointment_id) / p_analysis_weeks BETWEEN 15 AND 29 THEN 'Underutilized - Add Slots'
            ELSE 'Very Low - Review Availability'
        END AS workload_assessment
    FROM doctors d
    JOIN profiles pr ON d.user_id = pr.user_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
        AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL p_analysis_weeks WEEK)
    WHERE d.dept_id = p_dept_id
    GROUP BY d.doctor_id, pr.first_name, pr.last_name
    ORDER BY total_appointments DESC;
END //
DELIMITER ;

-- Procedure: Predict Appointment Demand
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_predict_appointment_demand(
    IN p_dept_id INT,
    IN p_forecast_days INT
)
BEGIN
    DECLARE v_avg_daily_appointments DECIMAL(10,2);
    DECLARE v_seasonal_factor DECIMAL(10,4);
    DECLARE v_trend_factor DECIMAL(10,4);
    DECLARE v_day_counter INT DEFAULT 1;
    DECLARE v_forecast_date DATE;
    DECLARE v_predicted_appointments INT;
    
    -- Calculate historical average
    SELECT AVG(daily_count) INTO v_avg_daily_appointments
    FROM (
        SELECT DATE(appointment_date) AS appt_date, COUNT(*) AS daily_count
        FROM appointments a
        JOIN doctors d ON a.doctor_id = d.doctor_id
        WHERE d.dept_id = p_dept_id
        AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
        GROUP BY DATE(appointment_date)
    ) daily_stats;
    
    -- Simple trend calculation (growth/decline rate)
    WITH MonthlyTrends AS (
        SELECT 
            MONTH(appointment_date) AS month_num,
            COUNT(*) AS monthly_count
        FROM appointments a
        JOIN doctors d ON a.doctor_id = d.doctor_id
        WHERE d.dept_id = p_dept_id
        AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
        GROUP BY MONTH(appointment_date)
    )
    SELECT 
        (MAX(monthly_count) - MIN(monthly_count)) / NULLIF(MIN(monthly_count), 0) / 6
    INTO v_trend_factor
    FROM MonthlyTrends;
    
    SET v_trend_factor = COALESCE(v_trend_factor, 0);
    
    -- Create temporary forecast table
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_demand_forecast (
        forecast_date DATE,
        day_name VARCHAR(20),
        predicted_appointments INT,
        confidence_level VARCHAR(20),
        staffing_recommendation VARCHAR(100)
    );
    
    TRUNCATE TABLE tmp_demand_forecast;
    
    -- Generate daily forecasts
    WHILE v_day_counter <= p_forecast_days DO
        SET v_forecast_date = DATE_ADD(CURDATE(), INTERVAL v_day_counter DAY);
        
        -- Day of week seasonal factor
        SET v_seasonal_factor = CASE DAYOFWEEK(v_forecast_date)
            WHEN 1 THEN 0.5  -- Sunday
            WHEN 2 THEN 1.2  -- Monday (busy)
            WHEN 3 THEN 1.1  -- Tuesday
            WHEN 4 THEN 1.0  -- Wednesday
            WHEN 5 THEN 1.1  -- Thursday
            WHEN 6 THEN 0.9  -- Friday
            WHEN 7 THEN 0.6  -- Saturday
        END;
        
        -- Calculate prediction
        SET v_predicted_appointments = ROUND(
            v_avg_daily_appointments * v_seasonal_factor * (1 + v_trend_factor * v_day_counter / 30)
        );
        
        INSERT INTO tmp_demand_forecast VALUES (
            v_forecast_date,
            DAYNAME(v_forecast_date),
            v_predicted_appointments,
            '70% Confidence',
            CASE 
                WHEN v_predicted_appointments >= 30 THEN 'Staff 4+ doctors'
                WHEN v_predicted_appointments >= 20 THEN 'Staff 3 doctors'
                WHEN v_predicted_appointments >= 10 THEN 'Staff 2 doctors'
                ELSE 'Staff 1 doctor'
            END
        );
        
        SET v_day_counter = v_day_counter + 1;
    END WHILE;
    
    SELECT * FROM tmp_demand_forecast ORDER BY forecast_date;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_demand_forecast;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- SECTION 5: QUALITY ASSURANCE AND COMPLIANCE MONITORING
-- ----------------------------------------------------------------------------

-- Procedure: Medical Records Completeness Audit
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_audit_medical_records_completeness()
BEGIN
    SELECT 
        'Medical Records Completeness Audit' AS audit_type,
        COUNT(*) AS total_appointments,
        COUNT(mr.record_id) AS appointments_with_records,
        COUNT(*) - COUNT(mr.record_id) AS missing_records,
        ROUND((COUNT(mr.record_id) * 100.0 / COUNT(*)), 2) AS completeness_percentage,
        CASE 
            WHEN (COUNT(mr.record_id) * 100.0 / COUNT(*)) >= 95 THEN 'Excellent'
            WHEN (COUNT(mr.record_id) * 100.0 / COUNT(*)) >= 85 THEN 'Good'
            WHEN (COUNT(mr.record_id) * 100.0 / COUNT(*)) >= 70 THEN 'Needs Improvement'
            ELSE 'Critical - Immediate Action Required'
        END AS compliance_status
    FROM appointments a
    LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
    WHERE a.status = 'Completed'
    AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY);
    
    -- Identify appointments without medical records
    SELECT 
        a.appointment_id,
        a.appointment_date,
        CONCAT(pat_prof.first_name, ' ', pat_prof.last_name) AS patient_name,
        CONCAT(doc_prof.first_name, ' ', doc_prof.last_name) AS doctor_name,
        dept.name AS department,
        DATEDIFF(CURDATE(), a.appointment_date) AS days_overdue,
        'Create medical record immediately' AS action_required
    FROM appointments a
    JOIN patients pat ON a.patient_id = pat.patient_id
    JOIN profiles pat_prof ON pat.user_id = pat_prof.user_id
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN profiles doc_prof ON d.user_id = doc_prof.user_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
    WHERE a.status = 'Completed'
    AND mr.record_id IS NULL
    AND a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    ORDER BY days_overdue DESC
    LIMIT 50;
END //
DELIMITER ;

-- Procedure: Invoice Payment Compliance Monitoring
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_monitor_payment_compliance()
BEGIN
    -- Overall payment statistics
    SELECT 
        'Payment Compliance Summary' AS report_section,
        COUNT(*) AS total_invoices,
        COUNT(CASE WHEN status = 'Paid' THEN 1 END) AS paid_invoices,
        COUNT(CASE WHEN status = 'Pending' THEN 1 END) AS pending_invoices,
        COUNT(CASE WHEN status = 'Overdue' THEN 1 END) AS overdue_invoices,
        ROUND((COUNT(CASE WHEN status = 'Paid' THEN 1 END) * 100.0 / COUNT(*)), 2) AS payment_rate_percentage,
        SUM(net_amount) AS total_invoiced,
        SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) AS total_collected,
        SUM(CASE WHEN status IN ('Pending', 'Overdue') THEN net_amount ELSE 0 END) AS outstanding_amount
    FROM invoices
    WHERE generated_at >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH);
    
    -- High-value overdue invoices
    SELECT 
        'High Priority Collections' AS report_section,
        i.invoice_id,
        i.generated_at,
        DATEDIFF(CURDATE(), i.generated_at) AS days_outstanding,
        i.net_amount,
        CONCAT(pr.first_name, ' ', pr.last_name) AS patient_name,
        pr.phone_number AS contact_phone,
        CASE 
            WHEN DATEDIFF(CURDATE(), i.generated_at) > 90 THEN 'Send to Collections'
            WHEN DATEDIFF(CURDATE(), i.generated_at) > 60 THEN 'Final Notice'
            WHEN DATEDIFF(CURDATE(), i.generated_at) > 30 THEN 'Second Reminder'
            ELSE 'First Reminder'
        END AS collection_action
    FROM invoices i
    JOIN appointments a ON i.appointment_id = a.appointment_id
    JOIN patients p ON a.patient_id = p.patient_id
    JOIN profiles pr ON p.user_id = pr.user_id
    WHERE i.status IN ('Pending', 'Overdue')
    ORDER BY i.net_amount DESC, days_outstanding DESC
    LIMIT 20;
    
    -- Payment patterns by department
    SELECT 
        'Payment Patterns by Department' AS report_section,
        dept.name AS department,
        COUNT(i.invoice_id) AS total_invoices,
        ROUND(AVG(CASE WHEN i.status = 'Paid' 
            THEN DATEDIFF(i.generated_at, a.appointment_date) END), 1) AS avg_payment_days,
        ROUND((COUNT(CASE WHEN i.status = 'Paid' THEN 1 END) * 100.0 / COUNT(*)), 2) AS payment_rate,
        SUM(i.net_amount) AS total_billed,
        SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) AS collected
    FROM invoices i
    JOIN appointments a ON i.appointment_id = a.appointment_id
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    WHERE i.generated_at >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
    GROUP BY dept.dept_id, dept.name
    ORDER BY payment_rate DESC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- SECTION 6: ADVANCED PATIENT ANALYTICS
-- ----------------------------------------------------------------------------

-- Procedure: Patient Cohort Analysis
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_analyze_patient_cohorts(
    IN p_cohort_type VARCHAR(50)  -- 'age', 'gender', 'registration_month', 'department'
)
BEGIN
    IF p_cohort_type = 'age' THEN
        SELECT 
            CASE 
                WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) < 18 THEN '0-17 (Pediatric)'
                WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 18 AND 35 THEN '18-35 (Young Adult)'
                WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 36 AND 55 THEN '36-55 (Middle Age)'
                WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 56 AND 70 THEN '56-70 (Senior)'
                ELSE '70+ (Elderly)'
            END AS cohort,
            COUNT(DISTINCT p.patient_id) AS patient_count,
            COUNT(a.appointment_id) AS total_appointments,
            ROUND(COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT p.patient_id), 0), 2) AS avg_appointments_per_patient,
            ROUND(AVG(i.net_amount), 2) AS avg_invoice_amount,
            SUM(i.net_amount) AS total_revenue,
            ROUND((COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0 / 
                NULLIF(COUNT(a.appointment_id), 0)), 2) AS completion_rate
        FROM patients p
        JOIN profiles pr ON p.user_id = pr.user_id
        LEFT JOIN appointments a ON p.patient_id = a.patient_id
        LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
        WHERE pr.date_of_birth IS NOT NULL
        GROUP BY cohort
        ORDER BY patient_count DESC;
        
    ELSEIF p_cohort_type = 'gender' THEN
        SELECT 
            pr.gender AS cohort,
            COUNT(DISTINCT p.patient_id) AS patient_count,
            COUNT(a.appointment_id) AS total_appointments,
            ROUND(COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT p.patient_id), 0), 2) AS avg_appointments_per_patient,
            ROUND(AVG(i.net_amount), 2) AS avg_invoice_amount,
            SUM(i.net_amount) AS total_revenue,
            COUNT(DISTINCT CASE WHEN p.insurance_provider IS NOT NULL THEN p.patient_id END) AS insured_patients
        FROM patients p
        JOIN profiles pr ON p.user_id = pr.user_id
        LEFT JOIN appointments a ON p.patient_id = a.patient_id
        LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
        WHERE pr.gender IS NOT NULL
        GROUP BY pr.gender
        ORDER BY patient_count DESC;
        
    ELSEIF p_cohort_type = 'registration_month' THEN
        SELECT 
            DATE_FORMAT(u.created_at, '%Y-%m') AS cohort,
            COUNT(DISTINCT p.patient_id) AS patients_registered,
            COUNT(a.appointment_id) AS total_appointments,
            ROUND(COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT p.patient_id), 0), 2) AS appointments_per_patient,
            COUNT(DISTINCT CASE WHEN a.appointment_id IS NOT NULL THEN p.patient_id END) AS activated_patients,
            ROUND((COUNT(DISTINCT CASE WHEN a.appointment_id IS NOT NULL THEN p.patient_id END) * 100.0 / 
                NULLIF(COUNT(DISTINCT p.patient_id), 0)), 2) AS activation_rate,
            SUM(i.net_amount) AS cohort_revenue
        FROM patients p
        JOIN users u ON p.user_id = u.user_id
        LEFT JOIN appointments a ON p.patient_id = a.patient_id
        LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
        WHERE u.created_at >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
        GROUP BY cohort
        ORDER BY cohort DESC;
        
    ELSEIF p_cohort_type = 'department' THEN
        SELECT 
            dept.name AS cohort,
            COUNT(DISTINCT a.patient_id) AS unique_patients,
            COUNT(a.appointment_id) AS total_appointments,
            ROUND(COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT a.patient_id), 0), 2) AS avg_visits_per_patient,
            ROUND(AVG(i.net_amount), 2) AS avg_invoice_amount,
            SUM(i.net_amount) AS total_revenue,
            COUNT(DISTINCT a.doctor_id) AS doctors_in_dept
        FROM departments dept
        JOIN doctors d ON dept.dept_id = d.dept_id
        LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
        LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
        GROUP BY dept.dept_id, dept.name
        ORDER BY total_revenue DESC;
    END IF;
END //
DELIMITER ;

-- Procedure: Patient Churn Prediction
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_predict_patient_churn()
BEGIN
    SELECT 
        p.patient_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS patient_name,
        COUNT(a.appointment_id) AS total_visits,
        MAX(a.appointment_date) AS last_visit_date,
        DATEDIFF(CURDATE(), MAX(a.appointment_date)) AS days_since_last_visit,
        ROUND(AVG(DATEDIFF(
            a.appointment_date, 
            LAG(a.appointment_date) OVER (PARTITION BY a.patient_id ORDER BY a.appointment_date)
        )), 0) AS avg_days_between_visits,
        COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) AS cancelled_count,
        ROUND((COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) * 100.0 / 
            NULLIF(COUNT(a.appointment_id), 0)), 2) AS cancellation_rate,
        CASE 
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 365 THEN 95
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 180 THEN 75
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 90 THEN 50
            WHEN COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) > 3 THEN 60
            WHEN COUNT(a.appointment_id) = 1 AND DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 60 THEN 70
            ELSE 20
        END AS churn_risk_score,
        CASE 
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 365 THEN 'Critical - Likely Churned'
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 180 THEN 'High Risk - Immediate Intervention'
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 90 THEN 'Medium Risk - Re-engagement Campaign'
            WHEN COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) > 3 THEN 'Behavioral Risk - Contact ASAP'
            ELSE 'Low Risk - Active Patient'
        END AS churn_category,
        CASE 
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 365 THEN 'Archive or final re-engagement'
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 180 THEN 'Personal call from care coordinator'
            WHEN DATEDIFF(CURDATE(), MAX(a.appointment_date)) > 90 THEN 'Send health reminder and special offer'
            WHEN COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) > 3 THEN 'Investigate cancellation reasons'
            ELSE 'Continue standard care'
        END AS recommended_action
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.user_id
    JOIN appointments a ON p.patient_id = a.patient_id
    GROUP BY p.patient_id, pr.first_name, pr.last_name
    HAVING total_visits > 0
    ORDER BY churn_risk_score DESC, days_since_last_visit DESC
    LIMIT 100;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- SECTION 7: MEDICATION AND PHARMACY INTELLIGENCE
-- ----------------------------------------------------------------------------

-- Procedure: Medicine Interaction Checker
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_check_medicine_interactions(
    IN p_medicine_id_1 INT,
    IN p_medicine_id_2 INT
)
BEGIN
    DECLARE v_med1_name VARCHAR(200);
    DECLARE v_med2_name VARCHAR(200);
    DECLARE v_med1_category VARCHAR(100);
    DECLARE v_med2_category VARCHAR(100);
    DECLARE v_interaction_risk VARCHAR(50);
    DECLARE v_interaction_description TEXT;
    
    -- Get medicine details
    SELECT name, category INTO v_med1_name, v_med1_category
    FROM medicine WHERE medicine_id = p_medicine_id_1;
    
    SELECT name, category INTO v_med2_name, v_med2_category
    FROM medicine WHERE medicine_id = p_medicine_id_2;
    
    -- Simple interaction rules (would be much more complex in real system)
    IF v_med1_category = v_med2_category THEN
        SET v_interaction_risk = 'Moderate';
        SET v_interaction_description = 'Same category medicines - monitor for cumulative effects';
    ELSEIF (v_med1_category = 'Antibiotic' AND v_med2_category = 'Antacid') OR
           (v_med2_category = 'Antibiotic' AND v_med1_category = 'Antacid') THEN
        SET v_interaction_risk = 'High';
        SET v_interaction_description = 'Antacids may reduce antibiotic absorption - space dosing by 2+ hours';
    ELSEIF (v_med1_category LIKE '%Anti%' AND v_med2_category LIKE '%Anti%') THEN
        SET v_interaction_risk = 'Moderate';
        SET v_interaction_description = 'Multiple anti-inflammatory agents - monitor for GI effects';
    ELSE
        SET v_interaction_risk = 'Low';
        SET v_interaction_description = 'No known significant interactions';
    END IF;
    
    SELECT 
        v_med1_name AS medicine_1,
        v_med1_category AS category_1,
        v_med2_name AS medicine_2,
        v_med2_category AS category_2,
        v_interaction_risk AS interaction_risk_level,
        v_interaction_description AS interaction_details,
        CASE v_interaction_risk
            WHEN 'High' THEN 'Consult pharmacist or doctor before combining'
            WHEN 'Moderate' THEN 'Monitor patient closely for side effects'
            ELSE 'Safe to prescribe together with normal monitoring'
        END AS clinical_recommendation;
END //
DELIMITER ;

-- Procedure: Pharmacy Profitability Analysis
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_analyze_pharmacy_profitability()
BEGIN
    -- Top selling medicines
    SELECT 
        'Top Selling Medicines' AS analysis_category,
        m.name AS medicine_name,
        m.category,
        COUNT(ps.sale_id) AS total_sales,
        SUM(ps.quantity) AS total_units_sold,
        SUM(ps.total_price) AS total_revenue,
        m.price AS current_unit_price,
        ROUND(SUM(ps.total_price) / NULLIF(SUM(ps.quantity), 0), 2) AS avg_selling_price,
        m.quantity AS current_stock
    FROM medicine m
    LEFT JOIN pharmacy_sales ps ON m.medicine_id = ps.medicine_id
    WHERE ps.sale_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY m.medicine_id, m.name, m.category, m.price, m.quantity
    ORDER BY total_revenue DESC
    LIMIT 15;
    
    -- Category performance
    SELECT 
        'Category Performance' AS analysis_category,
        m.category,
        COUNT(DISTINCT m.medicine_id) AS unique_medicines,
        COUNT(ps.sale_id) AS total_transactions,
        SUM(ps.quantity) AS total_units_sold,
        SUM(ps.total_price) AS total_revenue,
        ROUND(AVG(ps.total_price), 2) AS avg_transaction_value,
        SUM(m.quantity) AS current_total_stock
    FROM medicine m
    LEFT JOIN pharmacy_sales ps ON m.medicine_id = ps.medicine_id
        AND ps.sale_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY m.category
    ORDER BY total_revenue DESC;
    
    -- Slow-moving inventory
    SELECT 
        'Slow Moving Inventory' AS analysis_category,
        m.medicine_id,
        m.name AS medicine_name,
        m.category,
        m.quantity AS current_stock,
        m.price AS unit_price,
        COALESCE(COUNT(ps.sale_id), 0) AS sales_last_90_days,
        COALESCE(SUM(ps.quantity), 0) AS units_sold_last_90_days,
        ROUND(m.quantity * m.price, 2) AS inventory_value_at_risk,
        CASE 
            WHEN COALESCE(COUNT(ps.sale_id), 0) = 0 THEN 'Consider discontinuing'
            WHEN COALESCE(COUNT(ps.sale_id), 0) < 3 THEN 'Reduce stock levels'
            ELSE 'Monitor closely'
        END AS recommendation
    FROM medicine m
    LEFT JOIN pharmacy_sales ps ON m.medicine_id = ps.medicine_id
        AND ps.sale_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY m.medicine_id, m.name, m.category, m.quantity, m.price
    HAVING sales_last_90_days < 5
    ORDER BY inventory_value_at_risk DESC
    LIMIT 20;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- SECTION 8: DOCTOR SPECIALIZATION AND EXPERTISE TRACKING
-- ----------------------------------------------------------------------------

-- Procedure: Doctor Expertise Profile Generator
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_generate_doctor_expertise_profile(
    IN p_doctor_id INT
)
BEGIN
    DECLARE v_doctor_name VARCHAR(200);
    DECLARE v_department VARCHAR(100);
    DECLARE v_specialization VARCHAR(100);
    DECLARE v_years_experience DECIMAL(5,2);
    
    -- Get doctor basic info
    SELECT 
        CONCAT(pr.first_name, ' ', pr.last_name),
        dept.name,
        d.specialization,
        ROUND(DATEDIFF(CURDATE(), d.joining_date) / 365.25, 2)
    INTO v_doctor_name, v_department, v_specialization, v_years_experience
    FROM doctors d
    JOIN profiles pr ON d.user_id = pr.user_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    WHERE d.doctor_id = p_doctor_id;
    
    -- Header information
    SELECT 
        'DOCTOR EXPERTISE PROFILE' AS profile_type,
        v_doctor_name AS doctor_name,
        v_department AS department,
        v_specialization AS specialization,
        v_years_experience AS years_in_practice,
        NOW() AS profile_generated_at;
    
    -- Case volume by diagnosis
    SELECT 
        'Case Volume Analysis' AS section,
        mr.diagnosis,
        COUNT(*) AS case_count,
        ROUND((COUNT(*) * 100.0 / (
            SELECT COUNT(*) FROM medical_records mr2
            JOIN appointments a2 ON mr2.appointment_id = a2.appointment_id
            WHERE a2.doctor_id = p_doctor_id
        )), 2) AS percentage_of_caseload,
        MIN(a.appointment_date) AS first_case,
        MAX(a.appointment_date) AS most_recent_case
    FROM medical_records mr
    JOIN appointments a ON mr.appointment_id = a.appointment_id
    WHERE a.doctor_id = p_doctor_id
    GROUP BY mr.diagnosis
    ORDER BY case_count DESC
    LIMIT 10;
    
    -- Procedure expertise
    SELECT 
        'Procedures Performed' AS section,
        mr.treatment_plan,
        COUNT(*) AS procedures_performed,
        MIN(a.appointment_date) AS first_performed,
        MAX(a.appointment_date) AS last_performed,
        ROUND(DATEDIFF(MAX(a.appointment_date), MIN(a.appointment_date)) / 365.25, 2) AS years_performing
    FROM medical_records mr
    JOIN appointments a ON mr.appointment_id = a.appointment_id
    WHERE a.doctor_id = p_doctor_id
    AND mr.treatment_plan IS NOT NULL
    AND mr.treatment_plan != ''
    GROUP BY mr.treatment_plan
    ORDER BY procedures_performed DESC
    LIMIT 10;
    
    -- Patient demographics served
    SELECT 
        'Patient Demographics' AS section,
        CASE 
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) < 18 THEN 'Pediatric (0-17)'
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 18 AND 35 THEN 'Young Adult (18-35)'
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 36 AND 55 THEN 'Middle Age (36-55)'
            WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 56 AND 70 THEN 'Senior (56-70)'
            ELSE 'Elderly (70+)'
        END AS age_group,
        pr.gender,
        COUNT(DISTINCT a.patient_id) AS unique_patients,
        COUNT(a.appointment_id) AS total_appointments
    FROM appointments a
    JOIN patients pat ON a.patient_id = pat.patient_id
    JOIN profiles pr ON pat.user_id = pr.user_id
    WHERE a.doctor_id = p_doctor_id
    AND pr.date_of_birth IS NOT NULL
    GROUP BY age_group, pr.gender
    ORDER BY total_appointments DESC;
    
    -- Collaboration patterns
    SELECT 
        'Interdepartmental Referrals' AS section,
        dept.name AS referred_to_department,
        COUNT(DISTINCT a2.patient_id) AS patients_referred,
        ROUND(AVG(DATEDIFF(a2.appointment_date, a1.appointment_date)), 1) AS avg_days_to_followup
    FROM appointments a1
    JOIN appointments a2 ON a1.patient_id = a2.patient_id AND a2.appointment_date > a1.appointment_date
    JOIN doctors d2 ON a2.doctor_id = d2.doctor_id
    JOIN departments dept ON d2.dept_id = dept.dept_id
    WHERE a1.doctor_id = p_doctor_id
    AND d2.dept_id != (SELECT dept_id FROM doctors WHERE doctor_id = p_doctor_id)
    GROUP BY dept.dept_id, dept.name
    ORDER BY patients_referred DESC
    LIMIT 10;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- SECTION 9: EMERGENCY AND TRIAGE SUPPORT SYSTEMS
-- ----------------------------------------------------------------------------

-- Procedure: Emergency Triage Scoring
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_calculate_emergency_triage_score(
    IN p_patient_id INT,
    IN p_chief_complaint TEXT,
    IN p_vital_signs JSON,
    OUT triage_level INT,
    OUT triage_category VARCHAR(50),
    OUT estimated_wait_time INT
)
BEGIN
    DECLARE v_age INT;
    DECLARE v_has_chronic_conditions BOOLEAN DEFAULT FALSE;
    DECLARE v_score INT DEFAULT 0;
    
    -- Get patient age
    SELECT TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) INTO v_age
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.user_id
    WHERE p.patient_id = p_patient_id;
    
    -- Check for chronic conditions
    SELECT COUNT(*) > 0 INTO v_has_chronic_conditions
    FROM medical_records mr
    JOIN appointments a ON mr.appointment_id = a.appointment_id
    WHERE a.patient_id = p_patient_id
    AND (
        LOWER(mr.diagnosis) LIKE '%chronic%' OR
        LOWER(mr.diagnosis) LIKE '%diabetes%' OR
        LOWER(mr.diagnosis) LIKE '%heart%' OR
        LOWER(mr.diagnosis) LIKE '%hypertension%'
    );
    
    -- Scoring based on chief complaint (simplified)
    IF LOWER(p_chief_complaint) LIKE '%chest pain%' OR
       LOWER(p_chief_complaint) LIKE '%heart attack%' OR
       LOWER(p_chief_complaint) LIKE '%stroke%' OR
       LOWER(p_chief_complaint) LIKE '%unconscious%' THEN
        SET v_score = v_score + 50;
    ELSEIF LOWER(p_chief_complaint) LIKE '%difficulty breathing%' OR
           LOWER(p_chief_complaint) LIKE '%severe bleeding%' OR
           LOWER(p_chief_complaint) LIKE '%severe pain%' THEN
        SET v_score = v_score + 35;
    ELSEIF LOWER(p_chief_complaint) LIKE '%fracture%' OR
           LOWER(p_chief_complaint) LIKE '%moderate pain%' THEN
        SET v_score = v_score + 20;
    ELSE
        SET v_score = v_score + 10;
    END IF;
    
    -- Age factor
    IF v_age > 65 THEN
        SET v_score = v_score + 10;
    ELSEIF v_age < 2 THEN
        SET v_score = v_score + 15;
    END IF;
    
    -- Chronic conditions
    IF v_has_chronic_conditions THEN
        SET v_score = v_score + 10;
    END IF;
    
    -- Determine triage level
    IF v_score >= 60 THEN
        SET triage_level = 1;
        SET triage_category = 'Critical - Immediate';
        SET estimated_wait_time = 0;
    ELSEIF v_score >= 40 THEN
        SET triage_level = 2;
        SET triage_category = 'Emergency - 15 minutes';
        SET estimated_wait_time = 15;
    ELSEIF v_score >= 25 THEN
        SET triage_level = 3;
        SET triage_category = 'Urgent - 30 minutes';
        SET estimated_wait_time = 30;
    ELSEIF v_score >= 15 THEN
        SET triage_level = 4;
        SET triage_category = 'Semi-Urgent - 60 minutes';
        SET estimated_wait_time = 60;
    ELSE
        SET triage_level = 5;
        SET triage_category = 'Non-Urgent - 120 minutes';
        SET estimated_wait_time = 120;
    END IF;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- SECTION 10: CONTINUOUS QUALITY IMPROVEMENT (CQI)
-- ----------------------------------------------------------------------------

-- Procedure: Generate Quality Improvement Dashboard
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_quality_improvement_dashboard(
    IN p_reporting_period_days INT
)
BEGIN
    DECLARE v_start_date DATE;
    SET v_start_date = DATE_SUB(CURDATE(), INTERVAL p_reporting_period_days DAY);
    
    -- Clinical documentation quality
    SELECT 
        'Clinical Documentation Quality' AS metric_category,
        COUNT(DISTINCT a.appointment_id) AS total_completed_appointments,
        COUNT(DISTINCT mr.record_id) AS appointments_documented,
        ROUND((COUNT(DISTINCT mr.record_id) * 100.0 / NULLIF(COUNT(DISTINCT a.appointment_id), 0)), 2) AS documentation_rate,
        COUNT(DISTINCT CASE 
            WHEN mr.diagnosis IS NOT NULL 
            AND mr.treatment_plan IS NOT NULL 
            AND mr.vitals IS NOT NULL 
            THEN mr.record_id 
        END) AS complete_records,
        ROUND((COUNT(DISTINCT CASE 
            WHEN mr.diagnosis IS NOT NULL 
            AND mr.treatment_plan IS NOT NULL 
            AND mr.vitals IS NOT NULL 
            THEN mr.record_id 
        END) * 100.0 / NULLIF(COUNT(DISTINCT mr.record_id), 0)), 2) AS completeness_rate
    FROM appointments a
    LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
    WHERE a.status = 'Completed'
    AND a.appointment_date >= v_start_date;
    
    -- Appointment scheduling efficiency
    SELECT 
        'Appointment Scheduling Efficiency' AS metric_category,
        COUNT(*) AS total_appointments,
        ROUND(AVG(DATEDIFF(appointment_date, created_at)), 1) AS avg_booking_lead_days,
        COUNT(CASE WHEN status = 'Completed' THEN 1 END) AS completed,
        COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) AS cancelled,
        COUNT(CASE WHEN status = 'Scheduled' AND appointment_date < CURDATE() THEN 1 END) AS no_shows,
        ROUND((COUNT(CASE WHEN status = 'Completed' THEN 1 END) * 100.0 / COUNT(*)), 2) AS completion_rate,
        ROUND((COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*)), 2) AS cancellation_rate
    FROM appointments
    WHERE appointment_date >= v_start_date;
    
    -- Financial efficiency
    SELECT 
        'Financial Efficiency' AS metric_category,
        COUNT(*) AS total_invoices,
        SUM(net_amount) AS total_invoiced,
        SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) AS total_collected,
        SUM(CASE WHEN status IN ('Pending', 'Overdue') THEN net_amount ELSE 0 END) AS outstanding,
        ROUND((SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) * 100.0 / NULLIF(SUM(net_amount), 0)), 2) AS collection_rate,
        ROUND(AVG(CASE WHEN status = 'Paid' 
            THEN DATEDIFF(generated_at, (SELECT appointment_date FROM appointments WHERE appointment_id = invoices.appointment_id))
        END), 1) AS avg_days_to_payment
    FROM invoices
    WHERE generated_at >= v_start_date;
    
    -- Resource utilization
    SELECT 
        'Resource Utilization' AS metric_category,
        COUNT(DISTINCT d.doctor_id) AS active_doctors,
        COUNT(DISTINCT a.appointment_id) AS appointments_served,
        ROUND(COUNT(DISTINCT a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0), 2) AS appointments_per_doctor,
        COUNT(DISTINCT rb.room_id) AS rooms_used,
        COUNT(DISTINCT pt.test_id) AS unique_tests_performed,
        COUNT(DISTINCT ps.medicine_id) AS unique_medicines_sold
    FROM doctors d
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id AND a.appointment_date >= v_start_date
    LEFT JOIN room_bookings rb ON rb.booking_date >= v_start_date
    LEFT JOIN patient_tests pt ON pt.prescribed_date >= v_start_date
    LEFT JOIN pharmacy_sales ps ON ps.sale_date >= v_start_date;
    
    -- Key quality indicators summary
    SELECT 
        'Overall Quality Score' AS metric_category,
        ROUND(
            (
                -- Documentation rate (25 points)
                ((SELECT COUNT(DISTINCT mr.record_id) * 100.0 / NULLIF(COUNT(DISTINCT a.appointment_id), 0)
                  FROM appointments a
                  LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
                  WHERE a.status = 'Completed' AND a.appointment_date >= v_start_date) * 0.25) +
                
                -- Completion rate (25 points)
                ((SELECT COUNT(CASE WHEN status = 'Completed' THEN 1 END) * 100.0 / COUNT(*)
                  FROM appointments WHERE appointment_date >= v_start_date) * 0.25) +
                
                -- Collection rate (25 points)
                ((SELECT SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) * 100.0 / NULLIF(SUM(net_amount), 0)
                  FROM invoices WHERE generated_at >= v_start_date) * 0.25) +
                
                -- Patient retention proxy (25 points)
                ((SELECT COUNT(DISTINCT patient_id) * 100.0 / (SELECT COUNT(*) FROM patients)
                  FROM appointments WHERE appointment_date >= v_start_date) * 0.25)
            ), 2
        ) AS composite_quality_score,
        CASE 
            WHEN ROUND((
                ((SELECT COUNT(DISTINCT mr.record_id) * 100.0 / NULLIF(COUNT(DISTINCT a.appointment_id), 0)
                  FROM appointments a LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
                  WHERE a.status = 'Completed' AND a.appointment_date >= v_start_date) * 0.25) +
                ((SELECT COUNT(CASE WHEN status = 'Completed' THEN 1 END) * 100.0 / COUNT(*)
                  FROM appointments WHERE appointment_date >= v_start_date) * 0.25) +
                ((SELECT SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) * 100.0 / NULLIF(SUM(net_amount), 0)
                  FROM invoices WHERE generated_at >= v_start_date) * 0.25) +
                ((SELECT COUNT(DISTINCT patient_id) * 100.0 / (SELECT COUNT(*) FROM patients)
                  FROM appointments WHERE appointment_date >= v_start_date) * 0.25)
            ), 2) >= 90 THEN 'Excellent - Maintain Standards'
            WHEN ROUND((
                ((SELECT COUNT(DISTINCT mr.record_id) * 100.0 / NULLIF(COUNT(DISTINCT a.appointment_id), 0)
                  FROM appointments a LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
                  WHERE a.status = 'Completed' AND a.appointment_date >= v_start_date) * 0.25) +
                ((SELECT COUNT(CASE WHEN status = 'Completed' THEN 1 END) * 100.0 / COUNT(*)
                  FROM appointments WHERE appointment_date >= v_start_date) * 0.25) +
                ((SELECT SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) * 100.0 / NULLIF(SUM(net_amount), 0)
                  FROM invoices WHERE generated_at >= v_start_date) * 0.25) +
                ((SELECT COUNT(DISTINCT patient_id) * 100.0 / (SELECT COUNT(*) FROM patients)
                  FROM appointments WHERE appointment_date >= v_start_date) * 0.25)
            ), 2) >= 75 THEN 'Good - Minor Improvements Needed'
            WHEN ROUND((
                ((SELECT COUNT(DISTINCT mr.record_id) * 100.0 / NULLIF(COUNT(DISTINCT a.appointment_id), 0)
                  FROM appointments a LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
                  WHERE a.status = 'Completed' AND a.appointment_date >= v_start_date) * 0.25) +
                ((SELECT COUNT(CASE WHEN status = 'Completed' THEN 1 END) * 100.0 / COUNT(*)
                  FROM appointments WHERE appointment_date >= v_start_date) * 0.25) +
                ((SELECT SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) * 100.0 / NULLIF(SUM(net_amount), 0)
                  FROM invoices WHERE generated_at >= v_start_date) * 0.25) +
                ((SELECT COUNT(DISTINCT patient_id) * 100.0 / (SELECT COUNT(*) FROM patients)
                  FROM appointments WHERE appointment_date >= v_start_date) * 0.25)
            ), 2) >= 60 THEN 'Fair - Significant Improvement Required'
            ELSE 'Poor - Immediate Action Required'
        END AS performance_rating;
END //
DELIMITER ;

-- ============================================================================
-- END OF EXTENDED UTILITY LOGIC
-- All procedures above are standalone and do not affect main trigger logic
-- ============================================================================

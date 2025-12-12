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


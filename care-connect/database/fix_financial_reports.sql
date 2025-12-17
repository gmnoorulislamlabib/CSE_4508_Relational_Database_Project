USE careconnect;

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
DROP PROCEDURE IF EXISTS RecalculateFinancialReports;
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
DROP TRIGGER IF EXISTS trg_update_financials_on_payment;
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

-- Trigger on Invoices
DROP TRIGGER IF EXISTS trg_update_financials_on_invoice;
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

CALL RecalculateFinancialReports();

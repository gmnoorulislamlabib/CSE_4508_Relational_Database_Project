USE careconnect;

-- Enforce strict behavior for this session (prevents silent data issues)
SET SESSION sql_mode = 'STRICT_ALL_TABLES';

-- 1. Create Summary Table (unchanged structure)
CREATE TABLE IF NOT EXISTS financial_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    report_type ENUM('Yearly', 'Monthly', 'Weekly') NOT NULL,
    period_label VARCHAR(50) NOT NULL,
    total_revenue DECIMAL(15, 2) DEFAULT 0.00,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_report (report_type, period_label)
);

DELIMITER //

-- 2. Procedure to Backfill / Fully Recalculate Financial Reports
DROP PROCEDURE IF EXISTS RecalculateFinancialReports;
CREATE PROCEDURE RecalculateFinancialReports()
BEGIN
    -- Ensure atomic rebuild (no partial state on failure)
    START TRANSACTION;

    -- Full rebuild strategy: clear first to avoid double counting
    TRUNCATE TABLE financial_reports;

    /* =======================
       YEARLY AGGREGATION
       ======================= */

    -- Payments
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT
        'Yearly',
        DATE_FORMAT(payment_date, '%Y'),
        IFNULL(SUM(amount), 0.00)
    FROM payments
    GROUP BY DATE_FORMAT(payment_date, '%Y');

    -- Paid Test Invoices
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT
        'Yearly',
        DATE_FORMAT(generated_at, '%Y'),
        IFNULL(SUM(net_amount), 0.00)
    FROM invoices
    WHERE status = 'Paid'
      AND test_record_id IS NOT NULL
    GROUP BY DATE_FORMAT(generated_at, '%Y')
    ON DUPLICATE KEY UPDATE
        total_revenue = total_revenue + VALUES(total_revenue);

    /* =======================
       MONTHLY AGGREGATION
       ======================= */

    -- Payments
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT
        'Monthly',
        DATE_FORMAT(payment_date, '%Y-%m'),
        IFNULL(SUM(amount), 0.00)
    FROM payments
    GROUP BY DATE_FORMAT(payment_date, '%Y-%m');

    -- Paid Test Invoices
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT
        'Monthly',
        DATE_FORMAT(generated_at, '%Y-%m'),
        IFNULL(SUM(net_amount), 0.00)
    FROM invoices
    WHERE status = 'Paid'
      AND test_record_id IS NOT NULL
    GROUP BY DATE_FORMAT(generated_at, '%Y-%m')
    ON DUPLICATE KEY UPDATE
        total_revenue = total_revenue + VALUES(total_revenue);

    /* =======================
       WEEKLY AGGREGATION (ISO WEEK)
       ======================= */

    -- Payments
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT
        'Weekly',
        DATE_FORMAT(payment_date, '%x-W%v'),
        IFNULL(SUM(amount), 0.00)
    FROM payments
    GROUP BY DATE_FORMAT(payment_date, '%x-W%v');

    -- Paid Test Invoices
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    SELECT
        'Weekly',
        DATE_FORMAT(generated_at, '%x-W%v'),
        IFNULL(SUM(net_amount), 0.00)
    FROM invoices
    WHERE status = 'Paid'
      AND test_record_id IS NOT NULL
    GROUP BY DATE_FORMAT(generated_at, '%x-W%v')
    ON DUPLICATE KEY UPDATE
        total_revenue = total_revenue + VALUES(total_revenue);

    COMMIT;
END //

/* =======================
   3. REAL-TIME TRIGGERS
   ======================= */

-- Payments trigger
DROP TRIGGER IF EXISTS trg_update_financials_on_payment;
CREATE TRIGGER trg_update_financials_on_payment
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    -- Yearly
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    VALUES ('Yearly', DATE_FORMAT(NEW.payment_date, '%Y'), NEW.amount)
    ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.amount;

    -- Monthly
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    VALUES ('Monthly', DATE_FORMAT(NEW.payment_date, '%Y-%m'), NEW.amount)
    ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.amount;

    -- Weekly
    INSERT INTO financial_reports (report_type, period_label, total_revenue)
    VALUES ('Weekly', DATE_FORMAT(NEW.payment_date, '%x-W%v'), NEW.amount)
    ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.amount;
END //

-- Invoices trigger
DROP TRIGGER IF EXISTS trg_update_financials_on_invoice;
CREATE TRIGGER trg_update_financials_on_invoice
AFTER INSERT ON invoices
FOR EACH ROW
BEGIN
    -- Only count paid test invoices
    IF NEW.status = 'Paid' AND NEW.test_record_id IS NOT NULL THEN

        -- Yearly
        INSERT INTO financial_reports (report_type, period_label, total_revenue)
        VALUES ('Yearly', DATE_FORMAT(NEW.generated_at, '%Y'), NEW.net_amount)
        ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.net_amount;

        -- Monthly
        INSERT INTO financial_reports (report_type, period_label, total_revenue)
        VALUES ('Monthly', DATE_FORMAT(NEW.generated_at, '%Y-%m'), NEW.net_amount)
        ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.net_amount;

        -- Weekly
        INSERT INTO financial_reports (report_type, period_label, total_revenue)
        VALUES ('Weekly', DATE_FORMAT(NEW.generated_at, '%x-W%v'), NEW.net_amount)
        ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.net_amount;

    END IF;
END //

DELIMITER ;

-- Initial full rebuild
CALL RecalculateFinancialReports();

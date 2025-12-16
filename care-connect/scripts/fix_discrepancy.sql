
-- Fix Missing Payments
CREATE TEMPORARY TABLE IF NOT EXISTS missing_pay_temp AS
SELECT invoice_id, net_amount, generated_at 
FROM invoices 
WHERE status = 'Paid' 
AND invoice_id NOT IN (SELECT invoice_id FROM payments);

INSERT INTO payments (invoice_id, amount, payment_method, payment_date) 
SELECT invoice_id, net_amount, 'Cash', generated_at FROM missing_pay_temp;

DROP TEMPORARY TABLE IF EXISTS missing_pay_temp;

-- Fix Procedure
DROP PROCEDURE IF EXISTS GetFinancialSummary;

DELIMITER //

CREATE PROCEDURE GetFinancialSummary()
BEGIN
    SELECT 
        IFNULL(SUM(amount), 0) as total_all_time,
        IFNULL(SUM(CASE WHEN payment_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR) THEN amount ELSE 0 END), 0) as total_last_year,
        IFNULL(SUM(CASE WHEN payment_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH) THEN amount ELSE 0 END), 0) as total_last_month,
        IFNULL(SUM(CASE WHEN payment_date >= DATE_SUB(NOW(), INTERVAL 1 WEEK) THEN amount ELSE 0 END), 0) as total_last_week
    FROM payments;
END //

DELIMITER ;

CALL RecalculateFinancialReports();

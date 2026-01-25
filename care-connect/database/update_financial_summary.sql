-- Update GetFinancialSummary to subtract Pharmacy Expenses

USE careconnect;

DELIMITER //

DROP PROCEDURE IF EXISTS GetFinancialSummary;

CREATE PROCEDURE GetFinancialSummary()
BEGIN
    SELECT 
        COALESCE(
            (SELECT COALESCE(SUM(amount), 0) FROM payments) + 
            (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND test_record_id IS NOT NULL),
            0
        ) - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock') as total_all_time,
        
        COALESCE(
            (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payment_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)) +
            (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND test_record_id IS NOT NULL AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 YEAR)),
            0
        ) - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)) as total_last_year,
        
        COALESCE(
            (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payment_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH)) +
            (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND test_record_id IS NOT NULL AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)),
            0
        ) - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH)) as total_last_month,
        
        COALESCE(
            (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payment_date >= DATE_SUB(NOW(), INTERVAL 1 WEEK)) +
            (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND test_record_id IS NOT NULL AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 WEEK)),
            0
        ) - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 WEEK)) as total_last_week;
END //

DELIMITER ;

USE careconnect;

DROP PROCEDURE IF EXISTS GetFinancialSummary;

DELIMITER //

CREATE PROCEDURE GetFinancialSummary()
BEGIN
    SELECT 
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid') 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock') as total_all_time,
        
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 YEAR)) 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)) as total_last_year,
        
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)) 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH)) as total_last_month,
        
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 WEEK)) 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 WEEK)) as total_last_week;
END //

DELIMITER ;

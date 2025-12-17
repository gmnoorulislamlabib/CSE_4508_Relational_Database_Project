USE careconnect;

DROP PROCEDURE IF EXISTS GetTotalEarnings;
DELIMITER //
CREATE PROCEDURE GetTotalEarnings(IN p_start_date DATETIME, IN p_end_date DATETIME)
BEGIN
    SELECT 
        (SELECT IFNULL(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at BETWEEN p_start_date AND p_end_date)
        -
        (SELECT IFNULL(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date BETWEEN p_start_date AND p_end_date)
    as total_earnings;
END //
DELIMITER ;

USE careconnect;

-- 1. Create Expenses Table
CREATE TABLE IF NOT EXISTS hospital_expenses (
    expense_id INT AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(50) NOT NULL, -- e.g., 'Pharmacy_Restock'
    description TEXT,
    amount DECIMAL(10, 2) NOT NULL,
    expense_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    recorded_by INT NULL
);

-- 2. Update GetFinancialSummary to Account for Expenses (Net Earning)
DROP PROCEDURE IF EXISTS GetFinancialSummary;
DELIMITER //
CREATE PROCEDURE GetFinancialSummary()
BEGIN
    DECLARE v_total_revenue DECIMAL(10, 2);
    DECLARE v_total_expenses DECIMAL(10, 2);
    
    -- Calculate Total Revenue (Inflow)
    SELECT COALESCE(
        (SELECT COALESCE(SUM(amount), 0) FROM payments) + 
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND test_record_id IS NOT NULL),
        0
    ) INTO v_total_revenue;

    -- Calculate Total Expenses (Outflow)
    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses FROM hospital_expenses;

    -- Return Stats
    SELECT 
        v_total_revenue AS total_revenue,
        v_total_expenses AS total_expenses,
        (v_total_revenue - v_total_expenses) AS total_all_time, -- Net Profit
        
        -- Yearly (Simplified for demo, expenses can be filtered by date too if needed but keeping it simple impact first)
        (
            SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payment_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)
        ) - (
            SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE expense_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)
        ) as total_last_year,

        -- Monthly
        (
            SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payment_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH)
        ) - (
            SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE expense_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH)
        ) as total_last_month,
        
        -- Weekly
         (
            SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payment_date >= DATE_SUB(NOW(), INTERVAL 1 WEEK)
        ) - (
            SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE expense_date >= DATE_SUB(NOW(), INTERVAL 1 WEEK)
        ) as total_last_week;
END //
DELIMITER ;

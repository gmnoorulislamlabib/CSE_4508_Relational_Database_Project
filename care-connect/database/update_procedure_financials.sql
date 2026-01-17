USE careconnect;

-- ============================================================================
-- COMPREHENSIVE FINANCIAL PROCEDURES AND ANALYTICS
-- Version: 2.0
-- Last Updated: 2026-01-28
-- Description: Complete financial management, reporting, and analysis procedures
-- ============================================================================

-- Main Financial Summary Procedure
DROP PROCEDURE IF EXISTS GetFinancialSummary;
DELIMITER //
CREATE PROCEDURE GetFinancialSummary()
BEGIN
    -- Calculate comprehensive financial metrics across all time periods
    SELECT 
        -- All-time financial summary
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid') 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock') as total_all_time,
        
        -- Yearly financial summary
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 YEAR)) 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)) as total_last_year,
        
        -- Monthly financial summary
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)) 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH)) as total_last_month,
        
        -- Weekly financial summary
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 WEEK)) 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 WEEK)) as total_last_week,
        
        -- Additional metrics
        (SELECT COUNT(*) FROM invoices WHERE status = 'Paid') as total_paid_invoices,
        (SELECT COUNT(*) FROM invoices WHERE status = 'Pending') as pending_invoices,
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Pending') as pending_revenue;
END //
DELIMITER ;

-- ============================================================================
-- DETAILED REVENUE BREAKDOWN PROCEDURES
-- ============================================================================

-- Procedure: Detailed Revenue Breakdown by Category
DROP PROCEDURE IF EXISTS GetDetailedRevenueBreakdown;
DELIMITER //
CREATE PROCEDURE GetDetailedRevenueBreakdown(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        revenue_category,
        revenue_subcategory,
        transaction_count,
        gross_revenue,
        discounts_given,
        net_revenue,
        outstanding_amount,
        ROUND(net_revenue * 100.0 / SUM(net_revenue) OVER(), 2) as revenue_percentage,
        ROUND(discounts_given * 100.0 / NULLIF(gross_revenue, 0), 2) as discount_rate
    FROM (
        -- Consultation Revenue
        SELECT 
            'Consultation' as revenue_category,
            dept.name as revenue_subcategory,
            COUNT(i.invoice_id) as transaction_count,
            SUM(i.total_amount) as gross_revenue,
            SUM(i.discount_amount) as discounts_given,
            SUM(i.net_amount) as net_revenue,
            SUM(CASE WHEN i.status = 'Pending' THEN i.net_amount ELSE 0 END) as outstanding_amount
        FROM invoices i
        INNER JOIN appointments a ON i.appointment_id = a.appointment_id
        INNER JOIN doctors d ON a.doctor_id = d.doctor_id
        INNER JOIN departments dept ON d.dept_id = dept.dept_id
        WHERE DATE(i.generated_at) BETWEEN p_start_date AND p_end_date
        GROUP BY dept.dept_id, dept.name
        
        UNION ALL
        
        -- Laboratory Services Revenue
        SELECT 
            'Laboratory' as revenue_category,
            'Diagnostic Tests' as revenue_subcategory,
            COUNT(i.invoice_id) as transaction_count,
            SUM(i.total_amount) as gross_revenue,
            SUM(i.discount_amount) as discounts_given,
            SUM(i.net_amount) as net_revenue,
            SUM(CASE WHEN i.status = 'Pending' THEN i.net_amount ELSE 0 END) as outstanding_amount
        FROM invoices i
        WHERE i.test_record_id IS NOT NULL
        AND DATE(i.generated_at) BETWEEN p_start_date AND p_end_date
        
        UNION ALL
        
        -- Pharmacy Revenue
        SELECT 
            'Pharmacy' as revenue_category,
            'Medication Sales' as revenue_subcategory,
            COUNT(i.invoice_id) as transaction_count,
            SUM(i.total_amount) as gross_revenue,
            SUM(i.discount_amount) as discounts_given,
            SUM(i.net_amount) as net_revenue,
            SUM(CASE WHEN i.status = 'Pending' THEN i.net_amount ELSE 0 END) as outstanding_amount
        FROM invoices i
        WHERE i.pharmacy_order_id IS NOT NULL
        AND DATE(i.generated_at) BETWEEN p_start_date AND p_end_date
    ) revenue_data
    ORDER BY net_revenue DESC;
END //
DELIMITER ;

-- Procedure: Expense Analysis and Categorization
DROP PROCEDURE IF EXISTS GetExpenseAnalysis;
DELIMITER //
CREATE PROCEDURE GetExpenseAnalysis(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        category as expense_category,
        COUNT(*) as transaction_count,
        SUM(amount) as total_expenses,
        AVG(amount) as avg_expense_amount,
        MIN(amount) as min_expense,
        MAX(amount) as max_expense,
        ROUND(SUM(amount) * 100.0 / (SELECT SUM(amount) FROM hospital_expenses 
            WHERE expense_date BETWEEN p_start_date AND p_end_date), 2) as expense_percentage
    FROM hospital_expenses
    WHERE expense_date BETWEEN p_start_date AND p_end_date
    GROUP BY category
    ORDER BY total_expenses DESC;
    
    -- Monthly expense trend
    SELECT 
        DATE_FORMAT(expense_date, '%Y-%m') as expense_month,
        category,
        COUNT(*) as expense_count,
        SUM(amount) as monthly_expense_total
    FROM hospital_expenses
    WHERE expense_date BETWEEN p_start_date AND p_end_date
    GROUP BY DATE_FORMAT(expense_date, '%Y-%m'), category
    ORDER BY expense_month DESC, monthly_expense_total DESC;
END //
DELIMITER ;

-- ============================================================================
-- PROFITABILITY AND MARGIN ANALYSIS
-- ============================================================================

-- Procedure: Department Profitability Analysis
DROP PROCEDURE IF EXISTS GetDepartmentProfitability;
DELIMITER //
CREATE PROCEDURE GetDepartmentProfitability(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        dept.name as department_name,
        COUNT(DISTINCT d.doctor_id) as doctor_count,
        COUNT(a.appointment_id) as appointment_count,
        SUM(i.total_amount) as gross_revenue,
        SUM(i.discount_amount) as total_discounts,
        SUM(i.net_amount) as net_revenue,
        SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) as collected_revenue,
        -- Estimated costs (doctor salaries approximation)
        COUNT(DISTINCT d.doctor_id) * 60000 * 
            DATEDIFF(p_end_date, p_start_date) / 30 as estimated_personnel_costs,
        -- Profit calculation
        SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) - 
            (COUNT(DISTINCT d.doctor_id) * 60000 * DATEDIFF(p_end_date, p_start_date) / 30) as estimated_profit,
        -- Profit margin
        ROUND(
            (SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) - 
            (COUNT(DISTINCT d.doctor_id) * 60000 * DATEDIFF(p_end_date, p_start_date) / 30)) * 100.0 /
            NULLIF(SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END), 0),
            2
        ) as profit_margin_percent
    FROM departments dept
    LEFT JOIN doctors d ON dept.dept_id = d.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
        AND DATE(a.appointment_date) BETWEEN p_start_date AND p_end_date
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
    GROUP BY dept.dept_id, dept.name
    HAVING net_revenue > 0
    ORDER BY estimated_profit DESC;
END //
DELIMITER ;

-- Procedure: Service-Level Profitability
DROP PROCEDURE IF EXISTS GetServiceProfitability;
DELIMITER //
CREATE PROCEDURE GetServiceProfitability(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    -- Consultation service profitability
    SELECT 
        'Consultation Services' as service_line,
        COUNT(*) as service_count,
        SUM(i.net_amount) as revenue,
        AVG(i.net_amount) as avg_revenue_per_service,
        SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) as collected,
        -- Cost approximation (30% of revenue for consultation services)
        SUM(i.net_amount) * 0.30 as estimated_cost,
        SUM(i.net_amount) * 0.70 as estimated_profit,
        70.00 as profit_margin_percent
    FROM invoices i
    INNER JOIN appointments a ON i.appointment_id = a.appointment_id
    WHERE DATE(i.generated_at) BETWEEN p_start_date AND p_end_date
    
    UNION ALL
    
    -- Laboratory service profitability
    SELECT 
        'Laboratory Services' as service_line,
        COUNT(*) as service_count,
        SUM(i.net_amount) as revenue,
        AVG(i.net_amount) as avg_revenue_per_service,
        SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) as collected,
        SUM(i.net_amount) * 0.40 as estimated_cost,
        SUM(i.net_amount) * 0.60 as estimated_profit,
        60.00 as profit_margin_percent
    FROM invoices i
    WHERE i.test_record_id IS NOT NULL
    AND DATE(i.generated_at) BETWEEN p_start_date AND p_end_date
    
    UNION ALL
    
    -- Pharmacy service profitability (with actual expenses)
    SELECT 
        'Pharmacy Services' as service_line,
        COUNT(i.invoice_id) as service_count,
        SUM(i.net_amount) as revenue,
        AVG(i.net_amount) as avg_revenue_per_service,
        SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) as collected,
        (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses 
         WHERE category = 'Pharmacy_Restock' 
         AND expense_date BETWEEN p_start_date AND p_end_date) as estimated_cost,
        SUM(i.net_amount) - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses 
         WHERE category = 'Pharmacy_Restock' 
         AND expense_date BETWEEN p_start_date AND p_end_date) as estimated_profit,
        ROUND(
            (SUM(i.net_amount) - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses 
             WHERE category = 'Pharmacy_Restock' 
             AND expense_date BETWEEN p_start_date AND p_end_date)) * 100.0 /
            NULLIF(SUM(i.net_amount), 0),
            2
        ) as profit_margin_percent
    FROM invoices i
    WHERE i.pharmacy_order_id IS NOT NULL
    AND DATE(i.generated_at) BETWEEN p_start_date AND p_end_date;
END //
DELIMITER ;

-- ============================================================================
-- CASH FLOW ANALYSIS PROCEDURES
-- ============================================================================

-- Procedure: Daily Cash Flow Analysis
DROP PROCEDURE IF EXISTS GetDailyCashFlow;
DELIMITER //
CREATE PROCEDURE GetDailyCashFlow(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        flow_date,
        SUM(cash_in) as total_cash_in,
        SUM(cash_out) as total_cash_out,
        SUM(cash_in) - SUM(cash_out) as net_cash_flow,
        SUM(SUM(cash_in) - SUM(cash_out)) OVER (ORDER BY flow_date) as cumulative_cash_flow
    FROM (
        -- Cash inflows from paid invoices
        SELECT 
            DATE(generated_at) as flow_date,
            SUM(net_amount) as cash_in,
            0 as cash_out
        FROM invoices
        WHERE status = 'Paid'
        AND DATE(generated_at) BETWEEN p_start_date AND p_end_date
        GROUP BY DATE(generated_at)
        
        UNION ALL
        
        -- Cash outflows from expenses
        SELECT 
            DATE(expense_date) as flow_date,
            0 as cash_in,
            SUM(amount) as cash_out
        FROM hospital_expenses
        WHERE DATE(expense_date) BETWEEN p_start_date AND p_end_date
        GROUP BY DATE(expense_date)
    ) cash_flows
    GROUP BY flow_date
    ORDER BY flow_date;
END //
DELIMITER ;

-- Procedure: Accounts Receivable Aging Report
DROP PROCEDURE IF EXISTS GetAccountsReceivableAging;
DELIMITER //
CREATE PROCEDURE GetAccountsReceivableAging()
BEGIN
    SELECT 
        aging_bucket,
        COUNT(*) as invoice_count,
        SUM(net_amount) as total_outstanding,
        ROUND(AVG(net_amount), 2) as avg_invoice_amount,
        ROUND(SUM(net_amount) * 100.0 / (SELECT SUM(net_amount) FROM invoices WHERE status IN ('Pending', 'Overdue')), 2) as percentage_of_ar
    FROM (
        SELECT 
            i.invoice_id,
            i.net_amount,
            CASE 
                WHEN DATEDIFF(CURDATE(), i.generated_at) <= 30 THEN '0-30 Days'
                WHEN DATEDIFF(CURDATE(), i.generated_at) <= 60 THEN '31-60 Days'
                WHEN DATEDIFF(CURDATE(), i.generated_at) <= 90 THEN '61-90 Days'
                WHEN DATEDIFF(CURDATE(), i.generated_at) <= 180 THEN '91-180 Days'
                ELSE 'Over 180 Days'
            END as aging_bucket
        FROM invoices i
        WHERE i.status IN ('Pending', 'Overdue')
    ) aged_invoices
    GROUP BY aging_bucket
    ORDER BY 
        CASE aging_bucket
            WHEN '0-30 Days' THEN 1
            WHEN '31-60 Days' THEN 2
            WHEN '61-90 Days' THEN 3
            WHEN '91-180 Days' THEN 4
            ELSE 5
        END;
END //
DELIMITER ;

-- ============================================================================
-- BUDGET VARIANCE AND FORECASTING
-- ============================================================================

-- Procedure: Budget vs Actual Analysis
DROP PROCEDURE IF EXISTS GetBudgetVarianceAnalysis;
DELIMITER //
CREATE PROCEDURE GetBudgetVarianceAnalysis(
    IN p_month DATE,
    IN p_monthly_budget DECIMAL(12,2)
)
BEGIN
    DECLARE v_actual_revenue DECIMAL(12,2);
    DECLARE v_actual_expenses DECIMAL(12,2);
    DECLARE v_net_actual DECIMAL(12,2);
    DECLARE v_budget_expense DECIMAL(12,2);
    
    -- Calculate actual revenue for the month
    SELECT COALESCE(SUM(net_amount), 0) INTO v_actual_revenue
    FROM invoices
    WHERE status = 'Paid'
    AND DATE_FORMAT(generated_at, '%Y-%m') = DATE_FORMAT(p_month, '%Y-%m');
    
    -- Calculate actual expenses for the month
    SELECT COALESCE(SUM(amount), 0) INTO v_actual_expenses
    FROM hospital_expenses
    WHERE DATE_FORMAT(expense_date, '%Y-%m') = DATE_FORMAT(p_month, '%Y-%m');
    
    -- Calculate net actual
    SET v_net_actual = v_actual_revenue - v_actual_expenses;
    
    -- Assume budget expenses are 40% of budget revenue
    SET v_budget_expense = p_monthly_budget * 0.40;
    
    -- Return variance analysis
    SELECT 
        DATE_FORMAT(p_month, '%M %Y') as analysis_month,
        p_monthly_budget as budgeted_revenue,
        v_actual_revenue as actual_revenue,
        v_actual_revenue - p_monthly_budget as revenue_variance,
        ROUND((v_actual_revenue - p_monthly_budget) * 100.0 / NULLIF(p_monthly_budget, 0), 2) as revenue_variance_percent,
        v_budget_expense as budgeted_expenses,
        v_actual_expenses as actual_expenses,
        v_actual_expenses - v_budget_expense as expense_variance,
        ROUND((v_actual_expenses - v_budget_expense) * 100.0 / NULLIF(v_budget_expense, 0), 2) as expense_variance_percent,
        (p_monthly_budget - v_budget_expense) as budgeted_profit,
        v_net_actual as actual_profit,
        v_net_actual - (p_monthly_budget - v_budget_expense) as profit_variance,
        CASE 
            WHEN v_actual_revenue >= p_monthly_budget THEN 'On Target'
            WHEN v_actual_revenue >= p_monthly_budget * 0.90 THEN 'Slight Underperformance'
            WHEN v_actual_revenue >= p_monthly_budget * 0.75 THEN 'Significant Underperformance'
            ELSE 'Critical Underperformance'
        END as performance_status;
END //
DELIMITER ;

-- Procedure: Revenue Forecasting Model
DROP PROCEDURE IF EXISTS GetRevenueForecast;
DELIMITER //
CREATE PROCEDURE GetRevenueForecast(
    IN p_forecast_months INT
)
BEGIN
    DECLARE v_avg_monthly_revenue DECIMAL(12,2);
    DECLARE v_growth_rate DECIMAL(10,4);
    DECLARE v_seasonality_factor DECIMAL(10,4);
    
    -- Calculate average monthly revenue from last 6 months
    SELECT AVG(monthly_revenue) INTO v_avg_monthly_revenue
    FROM (
        SELECT SUM(net_amount) as monthly_revenue
        FROM invoices
        WHERE status = 'Paid'
        AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
        GROUP BY DATE_FORMAT(generated_at, '%Y-%m')
    ) monthly_data;
    
    -- Calculate simple growth rate
    WITH MonthlyRevenue AS (
        SELECT 
            DATE_FORMAT(generated_at, '%Y-%m') as month_key,
            SUM(net_amount) as revenue
        FROM invoices
        WHERE status = 'Paid'
        AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
        GROUP BY DATE_FORMAT(generated_at, '%Y-%m')
    ),
    RevenueGrowth AS (
        SELECT 
            (revenue - LAG(revenue) OVER (ORDER BY month_key)) / 
            NULLIF(LAG(revenue) OVER (ORDER BY month_key), 0) as growth
        FROM MonthlyRevenue
    )
    SELECT AVG(growth) INTO v_growth_rate
    FROM RevenueGrowth
    WHERE growth IS NOT NULL;
    
    SET v_growth_rate = COALESCE(v_growth_rate, 0.03); -- Default 3% growth
    
    -- Generate forecast
    WITH RECURSIVE ForecastMonths AS (
        SELECT 1 as month_num, DATE_ADD(LAST_DAY(CURDATE()), INTERVAL 1 MONTH) as forecast_month
        UNION ALL
        SELECT month_num + 1, DATE_ADD(forecast_month, INTERVAL 1 MONTH)
        FROM ForecastMonths
        WHERE month_num < p_forecast_months
    )
    SELECT 
        month_num,
        DATE_FORMAT(forecast_month, '%M %Y') as forecast_period,
        ROUND(v_avg_monthly_revenue * POW(1 + v_growth_rate, month_num), 2) as forecasted_revenue,
        ROUND(v_avg_monthly_revenue * POW(1 + v_growth_rate, month_num) * 0.85, 2) as conservative_estimate,
        ROUND(v_avg_monthly_revenue * POW(1 + v_growth_rate, month_num) * 1.15, 2) as optimistic_estimate,
        ROUND(v_growth_rate * 100, 2) as assumed_growth_rate_percent
    FROM ForecastMonths
    ORDER BY month_num;
END //
DELIMITER ;

-- ============================================================================
-- PAYMENT COLLECTION AND EFFICIENCY METRICS
-- ============================================================================

-- Procedure: Collection Efficiency Analysis
DROP PROCEDURE IF EXISTS GetCollectionEfficiency;
DELIMITER //
CREATE PROCEDURE GetCollectionEfficiency(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        DATE_FORMAT(generated_at, '%Y-%m') as invoice_month,
        COUNT(*) as total_invoices,
        SUM(total_amount) as gross_billed,
        SUM(discount_amount) as discounts_applied,
        SUM(net_amount) as net_billed,
        SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) as collected,
        SUM(CASE WHEN status = 'Pending' THEN net_amount ELSE 0 END) as pending,
        SUM(CASE WHEN status = 'Overdue' THEN net_amount ELSE 0 END) as overdue,
        ROUND(
            SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) * 100.0 / 
            NULLIF(SUM(net_amount), 0),
            2
        ) as collection_rate_percent,
        ROUND(
            AVG(CASE WHEN status = 'Paid' 
                THEN DATEDIFF(generated_at, generated_at) END),
            1
        ) as avg_days_to_collection
    FROM invoices
    WHERE DATE(generated_at) BETWEEN p_start_date AND p_end_date
    GROUP BY DATE_FORMAT(generated_at, '%Y-%m')
    ORDER BY invoice_month DESC;
END //
DELIMITER ;

-- Procedure: Payment Method Analysis
DROP PROCEDURE IF EXISTS GetPaymentMethodAnalysis;
DELIMITER //
CREATE PROCEDURE GetPaymentMethodAnalysis(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        p.payment_method,
        COUNT(p.payment_id) as transaction_count,
        SUM(p.amount) as total_amount,
        ROUND(AVG(p.amount), 2) as avg_transaction_amount,
        MIN(p.amount) as min_amount,
        MAX(p.amount) as max_amount,
        ROUND(
            SUM(p.amount) * 100.0 / 
            (SELECT SUM(amount) FROM payments WHERE DATE(payment_date) BETWEEN p_start_date AND p_end_date),
            2
        ) as percentage_of_total_payments
    FROM payments p
    WHERE DATE(p.payment_date) BETWEEN p_start_date AND p_end_date
    GROUP BY p.payment_method
    ORDER BY total_amount DESC;
END //
DELIMITER ;

-- ============================================================================
-- COST ALLOCATION AND OVERHEAD ANALYSIS
-- ============================================================================

-- Procedure: Overhead Cost Allocation
DROP PROCEDURE IF EXISTS GetOverheadAllocation;
DELIMITER //
CREATE PROCEDURE GetOverheadAllocation(
    IN p_month DATE
)
BEGIN
    DECLARE v_total_overhead DECIMAL(12,2);
    
    -- Calculate total overhead for the month
    SELECT COALESCE(SUM(amount), 0) INTO v_total_overhead
    FROM hospital_expenses
    WHERE category NOT IN ('Pharmacy_Restock')
    AND DATE_FORMAT(expense_date, '%Y-%m') = DATE_FORMAT(p_month, '%Y-%m');
    
    -- Allocate overhead to departments based on revenue
    SELECT 
        dept.name as department_name,
        COALESCE(SUM(i.net_amount), 0) as department_revenue,
        ROUND(
            COALESCE(SUM(i.net_amount), 0) * 100.0 / 
            NULLIF((SELECT SUM(net_amount) FROM invoices i2 
                    JOIN appointments a2 ON i2.appointment_id = a2.appointment_id
                    WHERE DATE_FORMAT(i2.generated_at, '%Y-%m') = DATE_FORMAT(p_month, '%Y-%m')), 0),
            2
        ) as revenue_percentage,
        ROUND(
            v_total_overhead * COALESCE(SUM(i.net_amount), 0) / 
            NULLIF((SELECT SUM(net_amount) FROM invoices i2 
                    JOIN appointments a2 ON i2.appointment_id = a2.appointment_id
                    WHERE DATE_FORMAT(i2.generated_at, '%Y-%m') = DATE_FORMAT(p_month, '%Y-%m')), 0),
            2
        ) as allocated_overhead,
        COALESCE(SUM(i.net_amount), 0) - ROUND(
            v_total_overhead * COALESCE(SUM(i.net_amount), 0) / 
            NULLIF((SELECT SUM(net_amount) FROM invoices i2 
                    JOIN appointments a2 ON i2.appointment_id = a2.appointment_id
                    WHERE DATE_FORMAT(i2.generated_at, '%Y-%m') = DATE_FORMAT(p_month, '%Y-%m')), 0),
            2
        ) as contribution_after_overhead
    FROM departments dept
    LEFT JOIN doctors d ON dept.dept_id = d.dept_id
    LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
        AND DATE_FORMAT(a.appointment_date, '%Y-%m') = DATE_FORMAT(p_month, '%Y-%m')
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
        AND i.status = 'Paid'
    GROUP BY dept.dept_id, dept.name
    ORDER BY contribution_after_overhead DESC;
END //
DELIMITER ;

-- ============================================================================
-- KEY PERFORMANCE INDICATORS (KPIs)
-- ============================================================================

-- Procedure: Financial KPI Dashboard
DROP PROCEDURE IF EXISTS GetFinancialKPIs;
DELIMITER //
CREATE PROCEDURE GetFinancialKPIs(
    IN p_comparison_period_months INT
)
BEGIN
    -- Current period KPIs
    SELECT 
        'Current Month' as period_name,
        DATE_FORMAT(CURDATE(), '%M %Y') as period,
        (SELECT COUNT(*) FROM invoices 
         WHERE DATE_FORMAT(generated_at, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')) as total_invoices,
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices 
         WHERE status = 'Paid' 
         AND DATE_FORMAT(generated_at, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')) as revenue,
        (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses 
         WHERE DATE_FORMAT(expense_date, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')) as expenses,
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices 
         WHERE status = 'Paid' 
         AND DATE_FORMAT(generated_at, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')) -
        (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses 
         WHERE DATE_FORMAT(expense_date, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')) as net_profit,
        ROUND(
            ((SELECT COALESCE(SUM(net_amount), 0) FROM invoices 
              WHERE status = 'Paid' 
              AND DATE_FORMAT(generated_at, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')) -
             (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses 
              WHERE DATE_FORMAT(expense_date, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m'))) * 100.0 /
            NULLIF((SELECT COALESCE(SUM(net_amount), 0) FROM invoices 
                    WHERE status = 'Paid' 
                    AND DATE_FORMAT(generated_at, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')), 0),
            2
        ) as profit_margin_percent,
        ROUND(
            (SELECT COALESCE(SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END), 0) * 100.0 / 
             NULLIF(SUM(net_amount), 0) FROM invoices 
             WHERE DATE_FORMAT(generated_at, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')),
            2
        ) as collection_efficiency,
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices 
         WHERE status IN ('Pending', 'Overdue')) as accounts_receivable
    
    UNION ALL
    
    -- Comparison period KPIs
    SELECT 
        'Comparison Period' as period_name,
        DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%M %Y') as period,
        (SELECT COUNT(*) FROM invoices 
         WHERE DATE_FORMAT(generated_at, '%Y-%m') = 
               DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%Y-%m')) as total_invoices,
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices 
         WHERE status = 'Paid' 
         AND DATE_FORMAT(generated_at, '%Y-%m') = 
             DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%Y-%m')) as revenue,
        (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses 
         WHERE DATE_FORMAT(expense_date, '%Y-%m') = 
               DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%Y-%m')) as expenses,
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices 
         WHERE status = 'Paid' 
         AND DATE_FORMAT(generated_at, '%Y-%m') = 
             DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%Y-%m')) -
        (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses 
         WHERE DATE_FORMAT(expense_date, '%Y-%m') = 
               DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%Y-%m')) as net_profit,
        ROUND(
            ((SELECT COALESCE(SUM(net_amount), 0) FROM invoices 
              WHERE status = 'Paid' 
              AND DATE_FORMAT(generated_at, '%Y-%m') = 
                  DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%Y-%m')) -
             (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses 
              WHERE DATE_FORMAT(expense_date, '%Y-%m') = 
                    DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%Y-%m'))) * 100.0 /
            NULLIF((SELECT COALESCE(SUM(net_amount), 0) FROM invoices 
                    WHERE status = 'Paid' 
                    AND DATE_FORMAT(generated_at, '%Y-%m') = 
                        DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%Y-%m')), 0),
            2
        ) as profit_margin_percent,
        ROUND(
            (SELECT COALESCE(SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END), 0) * 100.0 / 
             NULLIF(SUM(net_amount), 0) FROM invoices 
             WHERE DATE_FORMAT(generated_at, '%Y-%m') = 
                   DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL p_comparison_period_months MONTH), '%Y-%m')),
            2
        ) as collection_efficiency,
        NULL as accounts_receivable;
END //
DELIMITER ;

-- ============================================================================
-- END OF FINANCIAL PROCEDURES
-- ============================================================================

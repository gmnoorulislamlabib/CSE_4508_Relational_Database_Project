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

-- ============================================================================
-- EXTENDED FINANCIAL UTILITIES (Non-intrusive additions)
-- Date: 2026-01-28
-- Note: Procedures below are standalone analytics helpers; they do not modify
--       core transactional logic and can be executed on-demand.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Procedure: Rolling Financial Metrics (7/30/90-day windows)
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetRollingFinancialMetrics;
CREATE PROCEDURE GetRollingFinancialMetrics()
BEGIN
    SELECT 
        'Last 7 Days' AS period_label,
        COALESCE(SUM(CASE WHEN status = 'Paid' AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) THEN net_amount END), 0) AS revenue,
        COALESCE(SUM(CASE WHEN status IN ('Pending','Overdue') AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) THEN net_amount END), 0) AS ar_open,
        COALESCE((SELECT SUM(amount) FROM hospital_expenses WHERE expense_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)), 0) AS expenses,
        COALESCE(SUM(CASE WHEN status = 'Paid' AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) THEN net_amount END), 0) -
        COALESCE((SELECT SUM(amount) FROM hospital_expenses WHERE expense_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)), 0) AS net_profit
    FROM invoices
    UNION ALL
    SELECT 
        'Last 30 Days',
        COALESCE(SUM(CASE WHEN status = 'Paid' AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN net_amount END), 0),
        COALESCE(SUM(CASE WHEN status IN ('Pending','Overdue') AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN net_amount END), 0),
        COALESCE((SELECT SUM(amount) FROM hospital_expenses WHERE expense_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)), 0),
        COALESCE(SUM(CASE WHEN status = 'Paid' AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN net_amount END), 0) -
        COALESCE((SELECT SUM(amount) FROM hospital_expenses WHERE expense_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)), 0)
    FROM invoices
    UNION ALL
    SELECT 
        'Last 90 Days',
        COALESCE(SUM(CASE WHEN status = 'Paid' AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN net_amount END), 0),
        COALESCE(SUM(CASE WHEN status IN ('Pending','Overdue') AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN net_amount END), 0),
        COALESCE((SELECT SUM(amount) FROM hospital_expenses WHERE expense_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)), 0),
        COALESCE(SUM(CASE WHEN status = 'Paid' AND generated_at >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN net_amount END), 0) -
        COALESCE((SELECT SUM(amount) FROM hospital_expenses WHERE expense_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)), 0)
    FROM invoices;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Revenue Heatmap by Day of Week and Hour
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetRevenueHeatmap;
CREATE PROCEDURE GetRevenueHeatmap(IN p_days_back INT)
BEGIN
    SELECT 
        DAYNAME(a.appointment_date) AS day_of_week,
        HOUR(a.appointment_date) AS hour_of_day,
        COUNT(*) AS encounters,
        COALESCE(SUM(i.net_amount), 0) AS total_revenue,
        ROUND(COALESCE(AVG(i.net_amount), 0), 2) AS avg_revenue
    FROM appointments a
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    WHERE a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL p_days_back DAY)
    GROUP BY day_of_week, hour_of_day
    ORDER BY total_revenue DESC, encounters DESC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Expense Heatmap by Category and Month
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetExpenseHeatmap;
CREATE PROCEDURE GetExpenseHeatmap(IN p_months_back INT)
BEGIN
    SELECT 
        DATE_FORMAT(expense_date, '%Y-%m') AS expense_month,
        category,
        COUNT(*) AS tx_count,
        SUM(amount) AS total_spend,
        ROUND(AVG(amount), 2) AS avg_spend
    FROM hospital_expenses
    WHERE expense_date >= DATE_SUB(CURDATE(), INTERVAL p_months_back MONTH)
    GROUP BY expense_month, category
    ORDER BY expense_month DESC, total_spend DESC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Insurance Revenue Analytics
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetInsuranceRevenueAnalytics;
CREATE PROCEDURE GetInsuranceRevenueAnalytics(IN p_start DATE, IN p_end DATE)
BEGIN
    SELECT 
        COALESCE(pat.insurance_provider, 'Self-Pay') AS payer,
        COUNT(i.invoice_id) AS invoices,
        SUM(i.net_amount) AS revenue,
        ROUND(AVG(i.net_amount), 2) AS avg_invoice,
        SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) AS collected,
        SUM(CASE WHEN i.status IN ('Pending','Overdue') THEN i.net_amount ELSE 0 END) AS outstanding
    FROM invoices i
    JOIN appointments a ON i.appointment_id = a.appointment_id
    JOIN patients pat ON a.patient_id = pat.patient_id
    WHERE DATE(i.generated_at) BETWEEN p_start AND p_end
    GROUP BY payer
    ORDER BY revenue DESC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Patient Balance Summary
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetPatientBalanceSummary;
CREATE PROCEDURE GetPatientBalanceSummary(IN p_min_outstanding DECIMAL(12,2))
BEGIN
    SELECT 
        a.patient_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS patient_name,
        COALESCE(SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount END), 0) AS total_paid,
        COALESCE(SUM(CASE WHEN i.status IN ('Pending','Overdue') THEN i.net_amount END), 0) AS outstanding_balance,
        COUNT(i.invoice_id) AS total_invoices,
        MAX(i.generated_at) AS last_invoice_date
    FROM appointments a
    JOIN profiles pr ON (SELECT user_id FROM patients WHERE patient_id = a.patient_id) = pr.user_id
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
    GROUP BY a.patient_id, pr.first_name, pr.last_name
    HAVING outstanding_balance >= p_min_outstanding
    ORDER BY outstanding_balance DESC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Discount Policy Audit
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetDiscountPolicyAudit;
CREATE PROCEDURE GetDiscountPolicyAudit(IN p_start DATE, IN p_end DATE)
BEGIN
    SELECT 
        CONCAT(pr.first_name, ' ', pr.last_name) AS authorized_by,
        u.role,
        COUNT(i.invoice_id) AS discounted_invoices,
        ROUND(AVG(i.discount_amount), 2) AS avg_discount_amount,
        ROUND(AVG(i.discount_amount / NULLIF(i.total_amount, 0) * 100), 2) AS avg_discount_percent,
        SUM(i.discount_amount) AS total_discounts
    FROM invoices i
    JOIN appointments a ON i.appointment_id = a.appointment_id
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN users u ON d.user_id = u.user_id
    JOIN profiles pr ON u.user_id = pr.user_id
    WHERE i.discount_amount > 0
      AND DATE(i.generated_at) BETWEEN p_start AND p_end
    GROUP BY authorized_by, u.role
    HAVING total_discounts > 0
    ORDER BY total_discounts DESC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Top Customers (Lifetime Value)
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetTopCustomers;
CREATE PROCEDURE GetTopCustomers(IN p_limit INT)
BEGIN
    SELECT 
        a.patient_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS patient_name,
        COUNT(DISTINCT a.appointment_id) AS visits,
        COALESCE(SUM(i.net_amount), 0) AS lifetime_value,
        ROUND(COALESCE(AVG(i.net_amount), 0), 2) AS avg_invoice_amount,
        MAX(i.generated_at) AS last_purchase
    FROM appointments a
    JOIN patients p ON a.patient_id = p.patient_id
    JOIN profiles pr ON p.user_id = pr.user_id
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    GROUP BY a.patient_id, pr.first_name, pr.last_name
    ORDER BY lifetime_value DESC, visits DESC
    LIMIT p_limit;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Low Margin Services
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetLowMarginServices;
CREATE PROCEDURE GetLowMarginServices(IN p_start DATE, IN p_end DATE)
BEGIN
    SELECT 
        'Consultation' AS service_line,
        COUNT(*) AS tx_count,
        SUM(i.net_amount) AS revenue,
        SUM(i.net_amount) * 0.30 AS estimated_cost,
        ROUND(SUM(i.net_amount) * 0.70, 2) AS estimated_margin
    FROM invoices i
    JOIN appointments a ON i.appointment_id = a.appointment_id
    WHERE DATE(i.generated_at) BETWEEN p_start AND p_end
    UNION ALL
    SELECT 
        'Laboratory',
        COUNT(*) AS tx_count,
        SUM(i.net_amount) AS revenue,
        SUM(i.net_amount) * 0.40 AS estimated_cost,
        ROUND(SUM(i.net_amount) * 0.60, 2) AS estimated_margin
    FROM invoices i
    WHERE i.test_record_id IS NOT NULL
      AND DATE(i.generated_at) BETWEEN p_start AND p_end
    UNION ALL
    SELECT 
        'Pharmacy',
        COUNT(i.invoice_id) AS tx_count,
        SUM(i.net_amount) AS revenue,
        (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date BETWEEN p_start AND p_end) AS estimated_cost,
        ROUND(SUM(i.net_amount) - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date BETWEEN p_start AND p_end), 2) AS estimated_margin
    FROM invoices i
    WHERE i.pharmacy_order_id IS NOT NULL
      AND DATE(i.generated_at) BETWEEN p_start AND p_end
    ORDER BY estimated_margin ASC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Financial Anomalies (Outlier Detection)
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetFinancialAnomalies;
CREATE PROCEDURE GetFinancialAnomalies(IN p_start DATE, IN p_end DATE)
BEGIN
    -- Identify unusually large invoices and sudden spikes per day
    SELECT 
        'Large Invoices' AS anomaly_type,
        i.invoice_id,
        i.net_amount,
        DATE(i.generated_at) AS invoice_date
    FROM invoices i
    WHERE DATE(i.generated_at) BETWEEN p_start AND p_end
      AND i.net_amount > (
            SELECT AVG(net_amount) + 3 * STDDEV_POP(net_amount)
            FROM invoices
            WHERE DATE(generated_at) BETWEEN p_start AND p_end
        )
    ORDER BY i.net_amount DESC
    LIMIT 50;

    SELECT 
        'Daily Revenue Spikes' AS anomaly_type,
        dday.invoice_date,
        dday.daily_revenue,
        ROUND((dday.daily_revenue - avg_tbl.avg_rev) / NULLIF(std_tbl.std_rev, 0), 2) AS z_score
    FROM (
        SELECT DATE(generated_at) AS invoice_date, SUM(net_amount) AS daily_revenue
        FROM invoices
        WHERE DATE(generated_at) BETWEEN p_start AND p_end
        GROUP BY DATE(generated_at)
    ) dday
    CROSS JOIN (
        SELECT AVG(net_amount) AS avg_rev FROM invoices WHERE DATE(generated_at) BETWEEN p_start AND p_end
    ) avg_tbl
    CROSS JOIN (
        SELECT STDDEV_POP(net_amount) AS std_rev FROM invoices WHERE DATE(generated_at) BETWEEN p_start AND p_end
    ) std_tbl
    WHERE (dday.daily_revenue - avg_tbl.avg_rev) > 3 * std_tbl.std_rev
    ORDER BY dday.daily_revenue DESC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Views: Financial Snapshots (read-only)
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_monthly_financial_snapshot;
CREATE VIEW v_monthly_financial_snapshot AS
SELECT 
    DATE_FORMAT(i.generated_at, '%Y-%m') AS month_key,
    COUNT(i.invoice_id) AS invoices,
    SUM(i.total_amount) AS gross,
    SUM(i.discount_amount) AS discounts,
    SUM(i.net_amount) AS net,
    SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) AS collected
FROM invoices i
GROUP BY month_key;

DROP VIEW IF EXISTS v_department_financials;
CREATE VIEW v_department_financials AS
SELECT 
    d.dept_id,
    d.name AS department,
    COUNT(a.appointment_id) AS appointments,
    SUM(i.net_amount) AS revenue,
    ROUND(AVG(i.net_amount), 2) AS avg_invoice
FROM departments d
LEFT JOIN doctors doc ON d.dept_id = doc.dept_id
LEFT JOIN appointments a ON doc.doctor_id = a.doctor_id
LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
GROUP BY d.dept_id, d.name;

-- ----------------------------------------------------------------------------
-- Function: pct(a,b) returns a/b*100 safely
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS pct;
DELIMITER //
CREATE FUNCTION pct(numerator DECIMAL(18,6), denominator DECIMAL(18,6))
RETURNS DECIMAL(18,6)
DETERMINISTIC
BEGIN
    RETURN (numerator / NULLIF(denominator, 0)) * 100.0;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Profitability by Hour (Operational KPI)
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetProfitabilityByHour;
CREATE PROCEDURE GetProfitabilityByHour(IN p_days_back INT)
BEGIN
    SELECT 
        HOUR(a.appointment_date) AS hour_of_day,
        COUNT(*) AS encounters,
        COALESCE(SUM(i.net_amount), 0) AS revenue,
        COALESCE((SELECT SUM(amount) FROM hospital_expenses WHERE expense_date >= DATE_SUB(CURDATE(), INTERVAL p_days_back DAY)), 0) / 24 AS avg_hourly_expense,
        COALESCE(SUM(i.net_amount), 0) - COALESCE((SELECT SUM(amount) FROM hospital_expenses WHERE expense_date >= DATE_SUB(CURDATE(), INTERVAL p_days_back DAY)), 0) / 24 AS est_hourly_profit
    FROM appointments a
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    WHERE a.appointment_date >= DATE_SUB(CURDATE(), INTERVAL p_days_back DAY)
    GROUP BY hour_of_day
    ORDER BY est_hourly_profit DESC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Department Quarterly Trend
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetDepartmentQuarterlyTrend;
CREATE PROCEDURE GetDepartmentQuarterlyTrend(IN p_year INT)
BEGIN
    SELECT 
        d.name AS department,
        QUARTER(i.generated_at) AS quarter,
        COUNT(i.invoice_id) AS invoices,
        SUM(i.net_amount) AS revenue,
        ROUND(AVG(i.net_amount), 2) AS avg_invoice
    FROM departments d
    LEFT JOIN doctors doc ON d.dept_id = doc.dept_id
    LEFT JOIN appointments a ON doc.doctor_id = a.doctor_id
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    WHERE YEAR(i.generated_at) = p_year
    GROUP BY d.dept_id, d.name, QUARTER(i.generated_at)
    ORDER BY department, quarter;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Payment Collection Funnel
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetPaymentCollectionFunnel;
CREATE PROCEDURE GetPaymentCollectionFunnel(IN p_start DATE, IN p_end DATE)
BEGIN
    SELECT 
        'Generated' AS stage,
        COUNT(*) AS invoices,
        SUM(net_amount) AS amount
    FROM invoices WHERE DATE(generated_at) BETWEEN p_start AND p_end
    UNION ALL
    SELECT 'Paid', COUNT(*), SUM(net_amount) FROM invoices WHERE status='Paid' AND DATE(generated_at) BETWEEN p_start AND p_end
    UNION ALL
    SELECT 'Pending', COUNT(*), SUM(net_amount) FROM invoices WHERE status='Pending' AND DATE(generated_at) BETWEEN p_start AND p_end
    UNION ALL
    SELECT 'Overdue', COUNT(*), SUM(net_amount) FROM invoices WHERE status='Overdue' AND DATE(generated_at) BETWEEN p_start AND p_end;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: AR Recovery Projection (simple model)
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetARRecoveryProjection;
CREATE PROCEDURE GetARRecoveryProjection(IN p_weeks INT)
BEGIN
    DECLARE v_current_ar DECIMAL(12,2);
    SELECT COALESCE(SUM(net_amount),0) INTO v_current_ar FROM invoices WHERE status IN ('Pending','Overdue');
    WITH RECURSIVE proj AS (
        SELECT 1 AS wk, v_current_ar * 0.10 AS recovered, v_current_ar * 0.90 AS remaining
        UNION ALL
        SELECT wk+1, remaining * 0.10, remaining * 0.90 FROM proj WHERE wk < p_weeks
    )
    SELECT wk AS week,
           ROUND(SUM(recovered) OVER (ORDER BY wk), 2) AS cumulative_recovered,
           ROUND(remaining, 2) AS remaining_ar
    FROM proj;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Doctor Revenue Contribution
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetDoctorRevenueContribution;
CREATE PROCEDURE GetDoctorRevenueContribution(IN p_start DATE, IN p_end DATE)
BEGIN
    SELECT 
        doc.doctor_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS doctor_name,
        d.name AS department,
        COUNT(a.appointment_id) AS appointments,
        COALESCE(SUM(i.net_amount), 0) AS revenue,
        ROUND(COALESCE(AVG(i.net_amount), 0), 2) AS avg_invoice
    FROM doctors doc
    JOIN profiles pr ON doc.user_id = pr.user_id
    JOIN departments d ON doc.dept_id = d.dept_id
    LEFT JOIN appointments a ON doc.doctor_id = a.doctor_id AND DATE(a.appointment_date) BETWEEN p_start AND p_end
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    GROUP BY doc.doctor_id, pr.first_name, pr.last_name, d.name
    HAVING appointments > 0
    ORDER BY revenue DESC;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Pharmacy Profit vs Restock
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetPharmacyProfitVsRestock;
CREATE PROCEDURE GetPharmacyProfitVsRestock(IN p_start DATE, IN p_end DATE)
BEGIN
    SELECT 
        COUNT(i.invoice_id) AS sales,
        SUM(i.net_amount) AS sales_revenue,
        (SELECT COALESCE(SUM(amount),0) FROM hospital_expenses WHERE category='Pharmacy_Restock' AND expense_date BETWEEN p_start AND p_end) AS restock_expense,
        ROUND(SUM(i.net_amount) - (SELECT COALESCE(SUM(amount),0) FROM hospital_expenses WHERE category='Pharmacy_Restock' AND expense_date BETWEEN p_start AND p_end), 2) AS profit,
        ROUND(pct(SUM(i.net_amount) - (SELECT COALESCE(SUM(amount),0) FROM hospital_expenses WHERE category='Pharmacy_Restock' AND expense_date BETWEEN p_start AND p_end), SUM(i.net_amount)), 2) AS margin_percent
    FROM invoices i
    WHERE i.pharmacy_order_id IS NOT NULL
      AND DATE(i.generated_at) BETWEEN p_start AND p_end;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- Procedure: Financial KPI Snapshot (monthly)
-- ----------------------------------------------------------------------------
DELIMITER //
DROP PROCEDURE IF EXISTS GetMonthlyFinancialKPISnapshot;
CREATE PROCEDURE GetMonthlyFinancialKPISnapshot(IN p_months_back INT)
BEGIN
    SELECT 
        DATE_FORMAT(i.generated_at, '%Y-%m') AS month_key,
        COUNT(*) AS invoices,
        SUM(net_amount) AS net_revenue,
        SUM(CASE WHEN status='Paid' THEN net_amount ELSE 0 END) AS collected,
        SUM(CASE WHEN status IN ('Pending','Overdue') THEN net_amount ELSE 0 END) AS ar_open,
        ROUND(pct(SUM(CASE WHEN status='Paid' THEN net_amount ELSE 0 END), SUM(net_amount)), 2) AS collection_rate
    FROM invoices i
    WHERE i.generated_at >= DATE_SUB(CURDATE(), INTERVAL p_months_back MONTH)
    GROUP BY month_key
    ORDER BY month_key DESC;
END //
DELIMITER ;

-- End of extended utilities

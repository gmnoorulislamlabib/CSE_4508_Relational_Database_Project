USE careconnect;

-- ============================================================================
-- ANALYTICS PROCEDURES FOR COMPREHENSIVE REPORTING
-- Updated: 2026-01-28
-- ============================================================================

-- Procedure: Enhanced Department Revenue Analytics
DROP PROCEDURE IF EXISTS GetDepartmentEarnings;
DELIMITER //
CREATE PROCEDURE GetDepartmentEarnings(
    IN p_start_date DATETIME, 
    IN p_end_date DATETIME
)
BEGIN
    -- Main revenue aggregation with detailed breakdown
    SELECT 
        department_name,
        SUM(revenue) as total_revenue,
        SUM(CASE WHEN revenue_source = 'Consultations' THEN revenue ELSE 0 END) as consultation_revenue,
        SUM(CASE WHEN revenue_source = 'Lab Tests' THEN revenue ELSE 0 END) as lab_revenue,
        SUM(CASE WHEN revenue_source = 'Pharmacy' THEN revenue ELSE 0 END) as pharmacy_revenue,
        SUM(CASE WHEN revenue_source = 'Expenses' THEN revenue ELSE 0 END) as expenses,
        COUNT(DISTINCT revenue_source) as revenue_streams
    FROM (
        -- Consultation Revenue by Department
        SELECT 
            d.name as department_name,
            'Consultations' as revenue_source,
            SUM(i.net_amount) as revenue
        FROM invoices i
        INNER JOIN appointments a ON i.appointment_id = a.appointment_id
        INNER JOIN doctors doc ON a.doctor_id = doc.doctor_id
        INNER JOIN departments d ON doc.dept_id = d.dept_id
        WHERE i.status = 'Paid'
        AND i.generated_at BETWEEN p_start_date AND p_end_date
        GROUP BY d.dept_id, d.name

        UNION ALL

        -- Laboratory & Diagnostics Revenue
        SELECT 
            'Laboratory & Diagnostics' as department_name,
            'Lab Tests' as revenue_source,
            SUM(i.net_amount) as revenue
        FROM invoices i
        WHERE i.test_record_id IS NOT NULL 
        AND i.status = 'Paid'
        AND i.generated_at BETWEEN p_start_date AND p_end_date

        UNION ALL

        -- Pharmacy Sales Revenue
        SELECT 
            'Pharmacy' as department_name,
            'Pharmacy' as revenue_source,
            SUM(i.net_amount) as revenue
        FROM invoices i
        WHERE i.pharmacy_order_id IS NOT NULL 
        AND i.status = 'Paid'
        AND i.generated_at BETWEEN p_start_date AND p_end_date

        UNION ALL

        -- Pharmacy Operational Expenses (Negative Revenue)
        SELECT 
            'Pharmacy' as department_name,
            'Expenses' as revenue_source,
            -(e.amount) as revenue
        FROM hospital_expenses e
        WHERE e.category = 'Pharmacy_Restock'
        AND e.expense_date BETWEEN p_start_date AND p_end_date

    ) as revenue_breakdown
    GROUP BY department_name
    HAVING total_revenue IS NOT NULL
    ORDER BY total_revenue DESC;
END //
DELIMITER ;

-- Procedure: Patient Volume Analytics by Department
DROP PROCEDURE IF EXISTS GetPatientVolumeByDepartment;
DELIMITER //
CREATE PROCEDURE GetPatientVolumeByDepartment(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        d.name AS department_name,
        COUNT(DISTINCT a.patient_id) AS unique_patients,
        COUNT(a.appointment_id) AS total_appointments,
        COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) AS completed_appointments,
        COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) AS cancelled_appointments,
        ROUND(
            COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0 / 
            NULLIF(COUNT(a.appointment_id), 0), 
            2
        ) AS completion_rate,
        ROUND(AVG(i.net_amount), 2) AS avg_revenue_per_visit
    FROM departments d
    LEFT JOIN doctors doc ON d.dept_id = doc.dept_id
    LEFT JOIN appointments a ON doc.doctor_id = a.doctor_id
        AND DATE(a.appointment_date) BETWEEN p_start_date AND p_end_date
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    GROUP BY d.dept_id, d.name
    ORDER BY unique_patients DESC;
END //
DELIMITER ;

-- Procedure: Monthly Revenue Trend Analysis
DROP PROCEDURE IF EXISTS GetMonthlyRevenueTrend;
DELIMITER //
CREATE PROCEDURE GetMonthlyRevenueTrend(
    IN p_months_back INT
)
BEGIN
    SELECT 
        DATE_FORMAT(generated_at, '%Y-%m') AS month_key,
        DATE_FORMAT(generated_at, '%M %Y') AS month_label,
        COUNT(*) AS invoice_count,
        SUM(total_amount) AS gross_revenue,
        SUM(discount_amount) AS total_discounts,
        SUM(net_amount) AS net_revenue,
        SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) AS collected_revenue,
        SUM(CASE WHEN status = 'Pending' THEN net_amount ELSE 0 END) AS pending_revenue,
        ROUND(
            SUM(CASE WHEN status = 'Paid' THEN net_amount ELSE 0 END) * 100.0 / 
            NULLIF(SUM(net_amount), 0),
            2
        ) AS collection_rate
    FROM invoices
    WHERE generated_at >= DATE_SUB(CURDATE(), INTERVAL p_months_back MONTH)
    GROUP BY DATE_FORMAT(generated_at, '%Y-%m'), DATE_FORMAT(generated_at, '%M %Y')
    ORDER BY month_key DESC;
END //
DELIMITER ;

-- Procedure: Top Performing Doctors Analytics
DROP PROCEDURE IF EXISTS GetTopPerformingDoctors;
DELIMITER //
CREATE PROCEDURE GetTopPerformingDoctors(
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_limit INT
)
BEGIN
    SELECT 
        doc.doctor_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS doctor_name,
        d.name AS department,
        doc.specialization,
        COUNT(DISTINCT a.appointment_id) AS total_appointments,
        COUNT(DISTINCT a.patient_id) AS unique_patients,
        COALESCE(SUM(i.net_amount), 0) AS revenue_generated,
        ROUND(COALESCE(AVG(i.net_amount), 0), 2) AS avg_revenue_per_visit,
        ROUND(
            COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0 / 
            NULLIF(COUNT(a.appointment_id), 0),
            2
        ) AS completion_rate
    FROM doctors doc
    INNER JOIN profiles pr ON doc.user_id = pr.user_id
    INNER JOIN departments d ON doc.dept_id = d.dept_id
    LEFT JOIN appointments a ON doc.doctor_id = a.doctor_id
        AND DATE(a.appointment_date) BETWEEN p_start_date AND p_end_date
    LEFT JOIN invoices i ON a.appointment_id = i.appointment_id AND i.status = 'Paid'
    GROUP BY doc.doctor_id, pr.first_name, pr.last_name, d.name, doc.specialization
    HAVING total_appointments > 0
    ORDER BY revenue_generated DESC, total_appointments DESC
    LIMIT p_limit;
END //
DELIMITER ;

-- Procedure: Revenue by Service Type
DROP PROCEDURE IF EXISTS GetRevenueByServiceType;
DELIMITER //
CREATE PROCEDURE GetRevenueByServiceType(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        service_type,
        transaction_count,
        total_revenue,
        avg_transaction_value,
        ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER(), 2) AS revenue_percentage
    FROM (
        -- Consultation Services
        SELECT 
            'Consultation Services' AS service_type,
            COUNT(*) AS transaction_count,
            SUM(i.net_amount) AS total_revenue,
            ROUND(AVG(i.net_amount), 2) AS avg_transaction_value
        FROM invoices i
        INNER JOIN appointments a ON i.appointment_id = a.appointment_id
        WHERE i.status = 'Paid'
        AND DATE(i.generated_at) BETWEEN p_start_date AND p_end_date
        
        UNION ALL
        
        -- Laboratory Services
        SELECT 
            'Laboratory Services' AS service_type,
            COUNT(*) AS transaction_count,
            SUM(i.net_amount) AS total_revenue,
            ROUND(AVG(i.net_amount), 2) AS avg_transaction_value
        FROM invoices i
        WHERE i.test_record_id IS NOT NULL
        AND i.status = 'Paid'
        AND DATE(i.generated_at) BETWEEN p_start_date AND p_end_date
        
        UNION ALL
        
        -- Pharmacy Services
        SELECT 
            'Pharmacy Services' AS service_type,
            COUNT(*) AS transaction_count,
            SUM(i.net_amount) AS total_revenue,
            ROUND(AVG(i.net_amount), 2) AS avg_transaction_value
        FROM invoices i
        WHERE i.pharmacy_order_id IS NOT NULL
        AND i.status = 'Paid'
        AND DATE(i.generated_at) BETWEEN p_start_date AND p_end_date
    ) service_breakdown
    ORDER BY total_revenue DESC;
END //
DELIMITER ;

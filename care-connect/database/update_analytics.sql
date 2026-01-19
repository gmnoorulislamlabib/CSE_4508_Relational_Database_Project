USE careconnect;


DROP PROCEDURE IF EXISTS GetDepartmentEarnings;
DROP PROCEDURE IF EXISTS GetPatientVolumeByDepartment;
DROP PROCEDURE IF EXISTS GetMonthlyRevenueTrend;
DROP PROCEDURE IF EXISTS GetTopPerformingDoctors;
DROP PROCEDURE IF EXISTS GetRevenueByServiceType;

-- -----------------------------------------------------------------------------
-- Create procedures (use a single custom delimiter for all CREATEs)
-- -----------------------------------------------------------------------------
DELIMITER //

-- 1) Enhanced Department Revenue Analytics
CREATE PROCEDURE GetDepartmentEarnings(
    IN p_start_date DATETIME,
    IN p_end_date   DATETIME
)
BEGIN
    -- Input validation
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Start date and end date must not be NULL';
    END IF;

    IF p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Start date cannot be after end date';
    END IF;

    -- Revenue aggregation
    SELECT 
        department_name,
        COALESCE(SUM(revenue), 0) AS total_revenue,
        COALESCE(SUM(CASE WHEN revenue_source = 'Consultations' THEN revenue END), 0) AS consultation_revenue,
        COALESCE(SUM(CASE WHEN revenue_source = 'Lab Tests' THEN revenue END), 0) AS lab_revenue,
        COALESCE(SUM(CASE WHEN revenue_source = 'Pharmacy' THEN revenue END), 0) AS pharmacy_revenue,
        COALESCE(SUM(CASE WHEN revenue_source = 'Expenses' THEN revenue END), 0) AS expenses,
        COUNT(DISTINCT revenue_source) AS revenue_streams
    FROM (
        -- Consultations (grouped by department)
        SELECT 
            d.name AS department_name,
            'Consultations' AS revenue_source,
            SUM(COALESCE(i.net_amount, 0)) AS revenue
        FROM invoices i
        JOIN appointments a ON i.appointment_id = a.appointment_id
        JOIN doctors doc ON a.doctor_id = doc.doctor_id
        JOIN departments d ON doc.dept_id = d.dept_id
        WHERE i.status = 'Paid'
          AND i.generated_at >= p_start_date
          AND i.generated_at <  p_end_date
        GROUP BY d.dept_id, d.name

        UNION ALL

        -- Laboratory & Diagnostics (centralized)
        SELECT 
            'Laboratory & Diagnostics',
            'Lab Tests',
            SUM(COALESCE(i.net_amount, 0))
        FROM invoices i
        WHERE i.test_record_id IS NOT NULL
          AND i.status = 'Paid'
          AND i.generated_at >= p_start_date
          AND i.generated_at <  p_end_date

        UNION ALL

        -- Pharmacy Sales
        SELECT 
            'Pharmacy',
            'Pharmacy',
            SUM(COALESCE(i.net_amount, 0))
        FROM invoices i
        WHERE i.pharmacy_order_id IS NOT NULL
          AND i.status = 'Paid'
          AND i.generated_at >= p_start_date
          AND i.generated_at <  p_end_date

        UNION ALL

        -- Pharmacy Operational Expenses (negative values)
        SELECT 
            'Pharmacy',
            'Expenses',
            -SUM(COALESCE(e.amount, 0))
        FROM hospital_expenses e
        WHERE e.category = 'Pharmacy_Restock'
          AND e.expense_date >= p_start_date
          AND e.expense_date <  p_end_date
    ) revenue_breakdown
    GROUP BY department_name
    ORDER BY total_revenue DESC;
END //

-- 2) Patient Volume Analytics by Department
CREATE PROCEDURE GetPatientVolumeByDepartment(
    IN p_start_date DATE,
    IN p_end_date   DATE
)
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid date range';
    END IF;

    SELECT 
        d.name AS department_name,
        COUNT(DISTINCT a.patient_id) AS unique_patients,
        COUNT(a.appointment_id) AS total_appointments,
        SUM(a.status = 'Completed') AS completed_appointments,
        SUM(a.status = 'Cancelled') AS cancelled_appointments,
        ROUND(
            SUM(a.status = 'Completed') * 100.0 /
            NULLIF(COUNT(a.appointment_id), 0),
            2
        ) AS completion_rate,
        ROUND(COALESCE(AVG(i.net_amount), 0), 2) AS avg_revenue_per_visit
    FROM departments d
    LEFT JOIN doctors doc ON d.dept_id = doc.dept_id
    LEFT JOIN appointments a
        ON doc.doctor_id = a.doctor_id
       AND a.appointment_date >= p_start_date
       AND a.appointment_date <  DATE_ADD(p_end_date, INTERVAL 1 DAY)
    LEFT JOIN invoices i
        ON a.appointment_id = i.appointment_id
       AND i.status = 'Paid'
    GROUP BY d.dept_id, d.name
    ORDER BY unique_patients DESC;
END //

-- 3) Monthly Revenue Trend Analysis
CREATE PROCEDURE GetMonthlyRevenueTrend(
    IN p_months_back INT
)
BEGIN
    IF p_months_back IS NULL OR p_months_back <= 0 THEN
        SET p_months_back = 6;
    END IF;

    SELECT 
        DATE_FORMAT(generated_at, '%Y-%m') AS month_key,
        DATE_FORMAT(generated_at, '%M %Y') AS month_label,
        COUNT(*) AS invoice_count,
        SUM(COALESCE(total_amount, 0)) AS gross_revenue,
        SUM(COALESCE(discount_amount, 0)) AS total_discounts,
        SUM(COALESCE(net_amount, 0)) AS net_revenue,
        SUM(CASE WHEN status = 'Paid' THEN COALESCE(net_amount, 0) END) AS collected_revenue,
        SUM(CASE WHEN status = 'Pending' THEN COALESCE(net_amount, 0) END) AS pending_revenue,
        ROUND(
            SUM(CASE WHEN status = 'Paid' THEN COALESCE(net_amount, 0) END) * 100.0 /
            NULLIF(SUM(COALESCE(net_amount, 0)), 0),
            2
        ) AS collection_rate
    FROM invoices
    WHERE generated_at >= DATE_SUB(CURDATE(), INTERVAL p_months_back MONTH)
    GROUP BY month_key, month_label
    ORDER BY month_key DESC;
END //

-- 4) Top Performing Doctors Analytics
CREATE PROCEDURE GetTopPerformingDoctors(
    IN p_start_date DATE,
    IN p_end_date   DATE,
    IN p_limit      INT
)
BEGIN
    IF p_limit IS NULL OR p_limit <= 0 THEN
        SET p_limit = 10;
    END IF;

    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid date range';
    END IF;

    SELECT 
        doc.doctor_id,
        CONCAT(pr.first_name, ' ', pr.last_name) AS doctor_name,
        d.name AS department,
        doc.specialization,
        COUNT(a.appointment_id) AS total_appointments,
        COUNT(DISTINCT a.patient_id) AS unique_patients,
        COALESCE(SUM(i.net_amount), 0) AS revenue_generated,
        ROUND(COALESCE(AVG(i.net_amount), 0), 2) AS avg_revenue_per_visit,
        ROUND(
            SUM(a.status = 'Completed') * 100.0 /
            NULLIF(COUNT(a.appointment_id), 0),
            2
        ) AS completion_rate
    FROM doctors doc
    JOIN profiles pr ON doc.user_id = pr.user_id
    JOIN departments d ON doc.dept_id = d.dept_id
    LEFT JOIN appointments a
        ON doc.doctor_id = a.doctor_id
       AND a.appointment_date >= p_start_date
       AND a.appointment_date <  DATE_ADD(p_end_date, INTERVAL 1 DAY)
    LEFT JOIN invoices i
        ON a.appointment_id = i.appointment_id
       AND i.status = 'Paid'
    GROUP BY doc.doctor_id, pr.first_name, pr.last_name, d.name, doc.specialization
    HAVING total_appointments > 0
    ORDER BY revenue_generated DESC, total_appointments DESC
    LIMIT p_limit;
END //

-- 5) Revenue by Service Type
CREATE PROCEDURE GetRevenueByServiceType(
    IN p_start_date DATE,
    IN p_end_date   DATE
)
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid date range';
    END IF;

    SELECT 
        service_type,
        transaction_count,
        total_revenue,
        avg_transaction_value,
        ROUND(
            total_revenue * 100.0 /
            NULLIF(SUM(total_revenue) OVER (), 0),
            2
        ) AS revenue_percentage
    FROM (
        SELECT 
            'Consultation Services' AS service_type,
            COUNT(*) AS transaction_count,
            COALESCE(SUM(i.net_amount), 0) AS total_revenue,
            ROUND(COALESCE(AVG(i.net_amount), 0), 2) AS avg_transaction_value
        FROM invoices i
        JOIN appointments a ON i.appointment_id = a.appointment_id
        WHERE i.status = 'Paid'
          AND i.generated_at >= p_start_date
          AND i.generated_at <  DATE_ADD(p_end_date, INTERVAL 1 DAY)

        UNION ALL

        SELECT 
            'Laboratory Services',
            COUNT(*),
            COALESCE(SUM(i.net_amount), 0),
            ROUND(COALESCE(AVG(i.net_amount), 0), 2)
        FROM invoices i
        WHERE i.test_record_id IS NOT NULL
          AND i.status = 'Paid'
          AND i.generated_at >= p_start_date
          AND i.generated_at <  DATE_ADD(p_end_date, INTERVAL 1 DAY)

        UNION ALL

        SELECT 
            'Pharmacy Services',
            COUNT(*),
            COALESCE(SUM(i.net_amount), 0),
            ROUND(COALESCE(AVG(i.net_amount), 0), 2)
        FROM invoices i
        WHERE i.pharmacy_order_id IS NOT NULL
          AND i.status = 'Paid'
          AND i.generated_at >= p_start_date
          AND i.generated_at <  DATE_ADD(p_end_date, INTERVAL 1 DAY)
    ) t
    ORDER BY total_revenue DESC;
END //

-- Restore default delimiter
DELIMITER ;

-- End of file

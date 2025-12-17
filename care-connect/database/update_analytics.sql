USE careconnect;

DROP PROCEDURE IF EXISTS GetDepartmentEarnings;
DELIMITER //
CREATE PROCEDURE GetDepartmentEarnings(IN p_start_date DATETIME, IN p_end_date DATETIME)
BEGIN
    SELECT department_name, SUM(revenue) as total_revenue FROM (
        -- 1. Consultation Revenue
        SELECT 
            d.name as department_name,
            SUM(i.net_amount) as revenue
        FROM invoices i
        JOIN appointments a ON i.appointment_id = a.appointment_id
        JOIN doctors doc ON a.doctor_id = doc.doctor_id
        JOIN departments d ON doc.dept_id = d.dept_id
        WHERE i.status = 'Paid'
        AND i.generated_at BETWEEN p_start_date AND p_end_date
        GROUP BY d.name

        UNION ALL

        -- 2. Lab Test Revenue
        SELECT 
            'Laboratory & Diagnostics' as department_name,
            SUM(i.net_amount) as revenue
        FROM invoices i
        WHERE i.test_record_id IS NOT NULL 
        AND i.status = 'Paid'
        AND i.generated_at BETWEEN p_start_date AND p_end_date

        UNION ALL

        -- 3. Pharmacy Revenue
        SELECT 
            'Pharmacy' as department_name,
            SUM(i.net_amount) as revenue
        FROM invoices i
        WHERE i.pharmacy_order_id IS NOT NULL 
        AND i.status = 'Paid'
        AND i.generated_at BETWEEN p_start_date AND p_end_date
    ) as combined_data
    GROUP BY department_name
    ORDER BY total_revenue DESC;
END //
DELIMITER ;

-- 10+ Complex SQL Queries for Project Requirements

USE careconnect;

-- 1. Multi-table Join & Analytical Query
-- Report: List all appointments with Patient Name, Doctor Name, Dept, and Payment Status
SELECT 
    a.appointment_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    CONCAT(d_prof.first_name, ' ', d_prof.last_name) AS doctor_name,
    dept.name AS department,
    a.appointment_date,
    COALESCE(i.status, 'Not Billed') AS invoice_status
FROM appointments a
JOIN patients pat ON a.patient_id = pat.patient_id
JOIN profiles p ON pat.user_id = p.user_id
JOIN doctors d ON a.doctor_id = d.doctor_id
JOIN profiles d_prof ON d.user_id = d_prof.user_id
JOIN departments dept ON d.dept_id = dept.dept_id
LEFT JOIN invoices i ON a.appointment_id = i.appointment_id;

-- 2. Nested Subquery
-- Find Doctors who charge more than the average consultation fee
SELECT 
    CONCAT(d_prof.first_name, ' ', d_prof.last_name) AS doctor_name, 
    d.consultation_fee
FROM doctors d
JOIN profiles d_prof ON d.user_id = d_prof.user_id
WHERE d.consultation_fee > (SELECT AVG(consultation_fee) FROM doctors);

-- 3. ROLLUP Aggregation
-- Report: Total Revenue by Department and Doctor with subtotals
SELECT 
    dept.name AS department,
    CONCAT(p.first_name, ' ', p.last_name) AS doctor_name,
    SUM(i.net_amount) AS total_revenue
FROM invoices i
JOIN appointments a ON i.appointment_id = a.appointment_id
JOIN doctors d ON a.doctor_id = d.doctor_id
JOIN departments dept ON d.dept_id = dept.dept_id
JOIN profiles p ON d.user_id = p.user_id
GROUP BY dept.name, p.user_id WITH ROLLUP;

-- 4. Ranking (Window Function)
-- Rank patients by total spending
SELECT 
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    SUM(i.net_amount) AS total_spent,
    RANK() OVER (ORDER BY SUM(i.net_amount) DESC) AS spending_rank
FROM patients pat
JOIN profiles p ON pat.user_id = p.user_id
JOIN appointments a ON pat.patient_id = a.patient_id
JOIN invoices i ON a.appointment_id = i.appointment_id
GROUP BY pat.patient_id, p.first_name, p.last_name;

-- 5. JSON Query (Advanced Feature)
-- Find all medical records where blood pressure (systolic) is likely high (simple string check or proper extraction)
-- Assuming format "120/80" -> check if contains high value or extract
SELECT 
    mr.record_id,
    mr.diagnosis,
    JSON_UNQUOTE(JSON_EXTRACT(mr.vitals, '$.bp')) AS blood_pressure
FROM medical_records mr
WHERE CAST(SUBSTRING_INDEX(JSON_UNQUOTE(JSON_EXTRACT(mr.vitals, '$.bp')), '/', 1) AS UNSIGNED) > 140;

-- 6. Analytical Query (Moving Average)
-- Calculate 3-day moving average of appointment counts
SELECT 
    appointment_date,
    daily_count,
    AVG(daily_count) OVER (ORDER BY appointment_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3_days
FROM (
    SELECT DATE(appointment_date) as appointment_date, COUNT(*) as daily_count
    FROM appointments
    GROUP BY DATE(appointment_date)
) AS daily_stats;

-- 7. Common Table Expression (CTE)
-- Find patients who have visited both 'Cardiology' and 'Orthopedics'
WITH CardiologyPatients AS (
    SELECT DISTINCT a.patient_id
    FROM appointments a
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    WHERE dept.name = 'Cardiology'
),
OrthopedicsPatients AS (
    SELECT DISTINCT a.patient_id
    FROM appointments a
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    WHERE dept.name = 'Orthopedics'
)
SELECT 
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name
FROM patients pat
JOIN profiles p ON pat.user_id = p.user_id
WHERE pat.patient_id IN (SELECT patient_id FROM CardiologyPatients)
  AND pat.patient_id IN (SELECT patient_id FROM OrthopedicsPatients);

-- 8. Grouping Sets (Simulated via UNION ALL as MySQL doesn't natively support simple GROUPING SETS syntax widely like T-SQL until 8.0 specific versions)
-- Revenue by Year, Month, and Overall
SELECT YEAR(generated_at) as Year, MONTH(generated_at) as Month, SUM(net_amount) as Revenue
FROM invoices
GROUP BY YEAR(generated_at), MONTH(generated_at)
UNION ALL
SELECT YEAR(generated_at) as Year, NULL, SUM(net_amount) as Revenue
FROM invoices
GROUP BY YEAR(generated_at)
UNION ALL
SELECT NULL, NULL, SUM(net_amount) as Revenue
FROM invoices;

-- 9. Existence Check with NOT EXISTS
-- Find Doctors who have no appointments scheduled in the future
SELECT 
    CONCAT(p.first_name, ' ', p.last_name) AS doctor_name
FROM doctors d
JOIN profiles p ON d.user_id = p.user_id
WHERE NOT EXISTS (
    SELECT 1 FROM appointments a 
    WHERE a.doctor_id = d.doctor_id 
    AND a.appointment_date > NOW()
);

-- 10. Complex Trigger Audit History
-- View Audit trail with resolved user names
SELECT 
    al.log_id,
    al.table_name,
    al.action_type,
    al.record_id,
    al.old_value,
    al.new_value,
    CONCAT(p.first_name, ' ', p.last_name) AS changed_by_user,
    al.performed_at
FROM audit_logs al
LEFT JOIN users u ON al.performed_by = u.user_id
LEFT JOIN profiles p ON u.user_id = p.user_id
ORDER BY al.performed_at DESC;

-- =========================================================
-- EXTRA FUNCTIONALITIES (Non-Intrusive Utilities)
-- These queries provide additional analytics and insights
-- without modifying core system behavior
-- =========================================================

-- 11. Patient Retention Analysis
-- Calculate patient retention metrics by tracking repeat visits
SELECT 
    visit_frequency_category,
    COUNT(*) AS patient_count,
    ROUND(AVG(total_visits), 2) AS avg_visits,
    ROUND(AVG(months_since_first), 1) AS avg_months_as_patient
FROM (
    SELECT 
        pat.patient_id,
        COUNT(a.appointment_id) AS total_visits,
        TIMESTAMPDIFF(MONTH, MIN(a.appointment_date), MAX(a.appointment_date)) AS months_since_first,
        CASE 
            WHEN COUNT(a.appointment_id) = 1 THEN 'One-time Visitor'
            WHEN COUNT(a.appointment_id) BETWEEN 2 AND 5 THEN 'Occasional Patient'
            WHEN COUNT(a.appointment_id) BETWEEN 6 AND 10 THEN 'Regular Patient'
            ELSE 'Frequent Patient'
        END AS visit_frequency_category
    FROM patients pat
    LEFT JOIN appointments a ON pat.patient_id = a.patient_id
    GROUP BY pat.patient_id
) patient_analysis
GROUP BY visit_frequency_category
ORDER BY patient_count DESC;

-- 12. Doctor Performance Scorecard
-- Comprehensive performance metrics per doctor (non-affecting, read-only)
SELECT 
    d.doctor_id,
    CONCAT(p.first_name, ' ', p.last_name) AS doctor_name,
    dept.name AS department,
    COUNT(DISTINCT a.appointment_id) AS total_appointments,
    COUNT(DISTINCT a.patient_id) AS unique_patients,
    ROUND(AVG(DATEDIFF(a.appointment_date, a.created_at)), 1) AS avg_booking_lead_days,
    COUNT(DISTINCT DATE(a.appointment_date)) AS days_worked,
    ROUND(COUNT(a.appointment_id) / NULLIF(COUNT(DISTINCT DATE(a.appointment_date)), 0), 2) AS appointments_per_working_day,
    SUM(i.net_amount) AS total_revenue_generated,
    ROUND(AVG(i.net_amount), 2) AS avg_revenue_per_appointment
FROM doctors d
JOIN profiles p ON d.user_id = p.user_id
JOIN departments dept ON d.dept_id = dept.dept_id
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
GROUP BY d.doctor_id, p.first_name, p.last_name, dept.name
HAVING total_appointments > 0
ORDER BY total_revenue_generated DESC;

-- 13. Time-Series Analysis: Appointment Trends
-- Weekly appointment trends with growth rate
WITH WeeklyStats AS (
    SELECT 
        YEARWEEK(appointment_date, 1) AS year_week,
        DATE(DATE_SUB(appointment_date, INTERVAL DAYOFWEEK(appointment_date)-2 DAY)) AS week_start,
        COUNT(*) AS appointment_count,
        COUNT(DISTINCT patient_id) AS unique_patients,
        COUNT(DISTINCT doctor_id) AS active_doctors
    FROM appointments
    GROUP BY YEARWEEK(appointment_date, 1), week_start
)
SELECT 
    week_start,
    appointment_count,
    unique_patients,
    active_doctors,
    LAG(appointment_count) OVER (ORDER BY week_start) AS prev_week_count,
    ROUND(
        ((appointment_count - LAG(appointment_count) OVER (ORDER BY week_start)) / 
        NULLIF(LAG(appointment_count) OVER (ORDER BY week_start), 0) * 100), 2
    ) AS growth_rate_percent
FROM WeeklyStats
ORDER BY week_start DESC
LIMIT 12;

-- 14. Department Capacity Utilization
-- Analyze department workload and resource utilization
SELECT 
    dept.name AS department,
    COUNT(DISTINCT d.doctor_id) AS total_doctors,
    COUNT(DISTINCT s.schedule_id) AS total_schedule_slots,
    COUNT(DISTINCT a.appointment_id) AS total_appointments,
    ROUND(COUNT(DISTINCT a.appointment_id) / NULLIF(COUNT(DISTINCT s.schedule_id), 0) * 100, 2) AS utilization_percent,
    ROUND(COUNT(DISTINCT a.appointment_id) / NULLIF(COUNT(DISTINCT d.doctor_id), 0), 2) AS appointments_per_doctor,
    SUM(i.net_amount) AS department_revenue,
    ROUND(AVG(d.consultation_fee), 2) AS avg_consultation_fee
FROM departments dept
LEFT JOIN doctors d ON dept.dept_id = d.dept_id
LEFT JOIN schedules s ON d.doctor_id = s.doctor_id
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
GROUP BY dept.dept_id, dept.name
ORDER BY department_revenue DESC;

-- 15. Medicine Inventory Forecast
-- Predict which medicines might need restocking based on usage patterns
SELECT 
    m.name AS medicine_name,
    m.quantity AS current_stock,
    COUNT(ps.sale_id) AS total_sales,
    SUM(ps.quantity) AS total_units_sold,
    ROUND(AVG(ps.quantity), 2) AS avg_quantity_per_sale,
    ROUND(SUM(ps.quantity) / NULLIF(DATEDIFF(MAX(ps.sale_date), MIN(ps.sale_date)), 0), 2) AS daily_consumption_rate,
    CASE 
        WHEN m.quantity / NULLIF((SUM(ps.quantity) / NULLIF(DATEDIFF(MAX(ps.sale_date), MIN(ps.sale_date)), 0)), 0) < 7 
        THEN 'Critical - Order Immediately'
        WHEN m.quantity / NULLIF((SUM(ps.quantity) / NULLIF(DATEDIFF(MAX(ps.sale_date), MIN(ps.sale_date)), 0)), 0) < 14 
        THEN 'Low - Order Soon'
        WHEN m.quantity / NULLIF((SUM(ps.quantity) / NULLIF(DATEDIFF(MAX(ps.sale_date), MIN(ps.sale_date)), 0)), 0) < 30 
        THEN 'Moderate - Monitor'
        ELSE 'Sufficient Stock'
    END AS stock_status,
    ROUND(m.quantity / NULLIF((SUM(ps.quantity) / NULLIF(DATEDIFF(MAX(ps.sale_date), MIN(ps.sale_date)), 0)), 0), 1) AS days_until_stockout
FROM medicine m
LEFT JOIN pharmacy_sales ps ON m.medicine_id = ps.medicine_id
WHERE ps.sale_date >= DATE_SUB(NOW(), INTERVAL 90 DAY)
GROUP BY m.medicine_id, m.name, m.quantity
HAVING total_sales > 0
ORDER BY days_until_stockout ASC;

-- 16. Patient Demographics Dashboard
-- Statistical breakdown of patient base for marketing/planning
SELECT 
    CASE 
        WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) < 18 THEN 'Pediatric (0-17)'
        WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 18 AND 35 THEN 'Young Adult (18-35)'
        WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 36 AND 55 THEN 'Middle Age (36-55)'
        WHEN TIMESTAMPDIFF(YEAR, pr.date_of_birth, CURDATE()) BETWEEN 56 AND 70 THEN 'Senior (56-70)'
        ELSE 'Elderly (70+)'
    END AS age_group,
    pr.gender,
    COUNT(DISTINCT pat.patient_id) AS patient_count,
    ROUND(COUNT(DISTINCT pat.patient_id) * 100.0 / (SELECT COUNT(*) FROM patients), 2) AS percentage_of_total,
    COUNT(DISTINCT a.appointment_id) AS total_appointments,
    ROUND(AVG(COALESCE(i.net_amount, 0)), 2) AS avg_invoice_amount,
    COUNT(DISTINCT CASE WHEN pat.insurance_provider IS NOT NULL THEN pat.patient_id END) AS insured_patients
FROM patients pat
JOIN profiles pr ON pat.user_id = pr.user_id
LEFT JOIN appointments a ON pat.patient_id = a.patient_id
LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
WHERE pr.date_of_birth IS NOT NULL
GROUP BY age_group, pr.gender
ORDER BY patient_count DESC;

-- 17. Cross-Department Referral Pattern
-- Identify common patient pathways between departments
WITH DepartmentVisits AS (
    SELECT 
        a.patient_id,
        dept.name AS department_name,
        a.appointment_date,
        ROW_NUMBER() OVER (PARTITION BY a.patient_id ORDER BY a.appointment_date) AS visit_sequence
    FROM appointments a
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN departments dept ON d.dept_id = dept.dept_id
)
SELECT 
    dv1.department_name AS from_department,
    dv2.department_name AS to_department,
    COUNT(DISTINCT dv1.patient_id) AS patient_referral_count,
    ROUND(AVG(DATEDIFF(dv2.appointment_date, dv1.appointment_date)), 1) AS avg_days_between_visits
FROM DepartmentVisits dv1
JOIN DepartmentVisits dv2 
    ON dv1.patient_id = dv2.patient_id 
    AND dv2.visit_sequence = dv1.visit_sequence + 1
WHERE dv1.department_name != dv2.department_name
GROUP BY dv1.department_name, dv2.department_name
HAVING patient_referral_count >= 2
ORDER BY patient_referral_count DESC
LIMIT 20;

-- 18. Financial Health Indicators
-- Key financial metrics for management decision making
SELECT 
    'Revenue Metrics' AS category,
    CONCAT('$', FORMAT(SUM(net_amount), 2)) AS total_value,
    CONCAT('$', FORMAT(AVG(net_amount), 2)) AS average_value,
    CONCAT('$', FORMAT(MAX(net_amount), 2)) AS maximum_value,
    COUNT(*) AS transaction_count
FROM invoices
WHERE status = 'Paid'
UNION ALL
SELECT 
    'Outstanding Invoices' AS category,
    CONCAT('$', FORMAT(SUM(net_amount), 2)) AS total_value,
    CONCAT('$', FORMAT(AVG(net_amount), 2)) AS average_value,
    CONCAT('$', FORMAT(MAX(net_amount), 2)) AS maximum_value,
    COUNT(*) AS transaction_count
FROM invoices
WHERE status = 'Pending'
UNION ALL
SELECT 
    'Pharmacy Revenue' AS category,
    CONCAT('$', FORMAT(SUM(total_price), 2)) AS total_value,
    CONCAT('$', FORMAT(AVG(total_price), 2)) AS average_value,
    CONCAT('$', FORMAT(MAX(total_price), 2)) AS maximum_value,
    COUNT(*) AS transaction_count
FROM pharmacy_sales;

-- 19. Appointment No-Show Analysis
-- Track appointment cancellations and no-shows for operational improvements
SELECT 
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) AS cancelled_count,
    COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) AS completed_count,
    COUNT(CASE WHEN a.status = 'Scheduled' AND a.appointment_date < NOW() THEN 1 END) AS no_show_count,
    COUNT(*) AS total_appointments,
    ROUND(COUNT(CASE WHEN a.status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*), 2) AS cancellation_rate,
    ROUND(COUNT(CASE WHEN a.status = 'Completed' THEN 1 END) * 100.0 / COUNT(*), 2) AS completion_rate
FROM appointments a
JOIN patients pat ON a.patient_id = pat.patient_id
JOIN profiles p ON pat.user_id = p.user_id
GROUP BY pat.patient_id, p.first_name, p.last_name
HAVING total_appointments >= 3
ORDER BY cancellation_rate DESC, no_show_count DESC
LIMIT 20;

-- 20. Room and Test Utilization Analytics
-- Comprehensive resource utilization report
SELECT 
    'Room Bookings' AS resource_type,
    COUNT(DISTINCT rb.room_id) AS unique_resources,
    COUNT(*) AS total_bookings,
    ROUND(AVG(rb.hours), 2) AS avg_usage_hours,
    SUM(rb.total_cost) AS total_revenue
FROM room_bookings rb
WHERE rb.status IN ('Confirmed', 'CheckedOut')
UNION ALL
SELECT 
    'Lab Tests' AS resource_type,
    COUNT(DISTINCT lt.test_id) AS unique_resources,
    COUNT(*) AS total_bookings,
    NULL AS avg_usage_hours,
    SUM(lt.price) AS total_revenue
FROM lab_tests lt
WHERE lt.status IN ('Completed', 'Reported');

-- 21. Peak Hours and Days Analysis
-- Identify busiest times for staff scheduling optimization
SELECT 
    DAYNAME(appointment_date) AS day_of_week,
    HOUR(appointment_date) AS hour_of_day,
    COUNT(*) AS appointment_count,
    COUNT(DISTINCT doctor_id) AS doctors_needed,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, appointment_date, 
        LEAD(appointment_date) OVER (ORDER BY appointment_date))), 0) AS avg_gap_minutes
FROM appointments
WHERE appointment_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY day_of_week, hour_of_day
HAVING appointment_count > 0
ORDER BY appointment_count DESC
LIMIT 15;

-- 22. Patient Satisfaction Proxy Metrics
-- Indirect satisfaction indicators based on behavior
WITH PatientMetrics AS (
    SELECT 
        pat.patient_id,
        CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
        COUNT(DISTINCT a.appointment_id) AS total_visits,
        COUNT(DISTINCT a.doctor_id) AS different_doctors_seen,
        COUNT(DISTINCT CASE WHEN a.status = 'Completed' THEN a.appointment_id END) AS completed_visits,
        DATEDIFF(MAX(a.appointment_date), MIN(a.appointment_date)) AS patient_tenure_days,
        AVG(DATEDIFF(a.appointment_date, a.created_at)) AS avg_booking_leadtime
    FROM patients pat
    JOIN profiles p ON pat.user_id = p.user_id
    LEFT JOIN appointments a ON pat.patient_id = a.patient_id
    GROUP BY pat.patient_id, p.first_name, p.last_name
    HAVING total_visits >= 2
)
SELECT 
    patient_name,
    total_visits,
    completed_visits,
    patient_tenure_days,
    ROUND(avg_booking_leadtime, 1) AS avg_booking_leadtime_days,
    CASE 
        WHEN different_doctors_seen = 1 AND total_visits > 3 THEN 'Highly Loyal'
        WHEN different_doctors_seen <= 2 AND total_visits > 2 THEN 'Loyal'
        WHEN completed_visits * 1.0 / total_visits > 0.8 THEN 'Engaged'
        ELSE 'Average'
    END AS loyalty_indicator,
    ROUND(completed_visits * 100.0 / total_visits, 1) AS completion_percentage
FROM PatientMetrics
ORDER BY loyalty_indicator DESC, total_visits DESC
LIMIT 25;


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


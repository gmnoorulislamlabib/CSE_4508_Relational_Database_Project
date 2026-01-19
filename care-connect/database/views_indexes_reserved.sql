-- Views and Indexing Strategies

USE careconnect;

-- =============================================
-- INDEXING STRATEGIES
-- =============================================
-- 1. Composite Index on Profiles for Fast Patient Search
-- Strategy: Queries often search by first and last name together.
CREATE INDEX idx_patient_name ON profiles(first_name, last_name);

-- 2. Index on Schedules for Day and Doctor
-- Strategy: Optimize `GetDoctorAvailability` queries.
CREATE INDEX idx_schedule_day ON schedules(doctor_id, day_of_week);

-- 3. Full text index on Medical Records diagnosis for search (Example)
-- CREATE FULLTEXT INDEX idx_diagnosis_search ON medical_records(diagnosis);


-- =============================================
-- VIEWS
-- =============================================

-- 1. Doctor Schedule View
-- Abstraction to list doctors with their meaningful names and schedules
CREATE OR REPLACE VIEW View_DoctorSchedule AS
SELECT 
    d.doctor_id,
    CONCAT(p.first_name, ' ', p.last_name) AS doctor_name,
    d.specialization,
    s.day_of_week,
    s.start_time,
    s.end_time,
    s.room_number
FROM doctors d
JOIN profiles p ON d.user_id = p.user_id
JOIN schedules s ON d.doctor_id = s.doctor_id;

-- 2. Patient Appointment History View
-- Reporting view for patients
CREATE OR REPLACE VIEW View_PatientHistory AS
SELECT 
    a.appointment_id,
    a.patient_id,
    CONCAT(pat_p.first_name, ' ', pat_p.last_name) AS patient_name,
    CONCAT(doc_p.first_name, ' ', doc_p.last_name) AS doctor_name,
    a.appointment_date,
    a.status,
    mr.diagnosis,
    i.total_amount,
    i.status AS payment_status
FROM appointments a
JOIN patients pat ON a.patient_id = pat.patient_id
JOIN profiles pat_p ON pat.user_id = pat_p.user_id
JOIN doctors d ON a.doctor_id = d.doctor_id
JOIN profiles doc_p ON d.user_id = doc_p.user_id
LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
LEFT JOIN invoices i ON a.appointment_id = i.appointment_id;

-- 3. Active Doctors Overview
-- Shows Doctor Name, Department, Specialization, and their Room Numbers
CREATE OR REPLACE VIEW View_ActiveDoctors AS
SELECT 
    d.doctor_id,
    CONCAT(p.first_name, ' ', p.last_name) AS doctor_name,
    dept.name AS department_name,
    d.specialization,
    -- Group their room numbers (e.g., "Rm-101, Rm-102") to avoid duplicates if they work multiple days in same room
    GROUP_CONCAT(DISTINCT COALESCE(r.room_number, s.room_number) ORDER BY r.room_number SEPARATOR ', ') AS room_numbers
FROM doctors d
JOIN profiles p ON d.user_id = p.user_id
JOIN departments dept ON d.dept_id = dept.dept_id
LEFT JOIN schedules s ON d.doctor_id = s.doctor_id
LEFT JOIN rooms r ON r.current_doctor_id = d.doctor_id
GROUP BY d.doctor_id, doctor_name, department_name, d.specialization;

-- 4. Available Rooms Overview (For Reception Desk)
CREATE OR REPLACE VIEW View_AvailableRooms AS
SELECT 
    room_number,
    type,
    charge_per_day,
    is_available
FROM rooms
WHERE is_available = TRUE;

-- =============================================
-- ADDITIONAL INDEXES
-- =============================================

-- 5. Index on Equipment Maintenance Next Date
CREATE INDEX idx_equipment_maintenance_date ON equipment_maintenance_log(next_maintenance_date);

-- 6. Index on Staff Attendance for Date Queries
CREATE INDEX idx_staff_attendance_date ON staff_attendance(user_id, attendance_date);

-- 7. Index on Leave Requests Status
CREATE INDEX idx_leave_status ON leave_requests(status, start_date);

-- 8. Index on Patient Feedback Rating
CREATE INDEX idx_feedback_rating ON patient_feedback(feedback_category, rating);

-- 9. Index on Blood Bank Type and Status
CREATE INDEX idx_blood_availability ON blood_bank(blood_type, rh_factor, status);

-- 10. Index on Ambulance Status
CREATE INDEX idx_ambulance_status ON ambulance_fleet(current_status);

-- 11. Index on Vaccination Records Patient
CREATE INDEX idx_vaccination_patient ON vaccination_records(patient_id, vaccination_date);

-- 12. Index on Medical Supplies Stock Level
CREATE INDEX idx_supply_stock ON medical_supplies(current_stock, reorder_level);

-- 13. Index on Equipment Status
CREATE INDEX idx_equipment_status ON equipment_inventory(current_status, assigned_dept_id);

-- 14. Index on Announcements Active Status
CREATE INDEX idx_announcements_active ON announcements(is_active, target_audience, expiry_date);

-- 15. Composite Index on Pharmacy Orders
CREATE INDEX idx_pharmacy_orders_status ON pharmacy_orders(status, patient_id);

-- 16. Index on Admissions Status
CREATE INDEX idx_admissions_status ON admissions(status, payment_status);

-- 17. Index on Expenses Date
CREATE INDEX idx_expenses_date ON hospital_expenses(expense_date, category);

-- 18. Index on Test Results Record
CREATE INDEX idx_test_results ON lab_results(record_id, test_id);

-- 19. Index on Supply Usage Date
CREATE INDEX idx_supply_usage_date ON supply_usage_log(usage_date, supply_id);

-- 20. Index on Certifications Expiry
CREATE INDEX idx_certifications_expiry ON staff_certifications(expiry_date, user_id);

-- =============================================
-- ADDITIONAL VIEWS
-- =============================================

-- 5. Equipment Maintenance Overview
CREATE OR REPLACE VIEW View_EquipmentMaintenanceDue AS
SELECT 
    ei.equipment_id,
    ei.equipment_name,
    ei.equipment_type,
    ei.current_status,
    ei.assigned_room,
    d.name AS department_name,
    eml.next_maintenance_date,
    DATEDIFF(eml.next_maintenance_date, CURDATE()) AS days_until_maintenance
FROM equipment_inventory ei
LEFT JOIN departments d ON ei.assigned_dept_id = d.dept_id
LEFT JOIN (
    SELECT equipment_id, MAX(maintenance_id) AS latest_maintenance
    FROM equipment_maintenance_log
    GROUP BY equipment_id
) latest ON ei.equipment_id = latest.equipment_id
LEFT JOIN equipment_maintenance_log eml ON latest.latest_maintenance = eml.maintenance_id
WHERE eml.next_maintenance_date IS NOT NULL
ORDER BY eml.next_maintenance_date ASC;

-- 6. Staff Attendance Summary
CREATE OR REPLACE VIEW View_StaffAttendanceSummary AS
SELECT 
    u.user_id,
    CONCAT(p.first_name, ' ', p.last_name) AS staff_name,
    u.role,
    COUNT(CASE WHEN sa.status = 'Present' THEN 1 END) AS days_present,
    COUNT(CASE WHEN sa.status = 'Absent' THEN 1 END) AS days_absent,
    COUNT(CASE WHEN sa.status = 'Late' THEN 1 END) AS days_late,
    COUNT(CASE WHEN sa.status = 'On_Leave' THEN 1 END) AS days_on_leave,
    COUNT(sa.attendance_id) AS total_days_recorded
FROM users u
JOIN profiles p ON u.user_id = p.user_id
LEFT JOIN staff_attendance sa ON u.user_id = sa.user_id
WHERE u.role IN ('Doctor', 'Staff', 'Admin')
GROUP BY u.user_id, staff_name, u.role;

-- 7. Blood Bank Inventory Overview
CREATE OR REPLACE VIEW View_BloodBankInventory AS
SELECT 
    blood_type,
    rh_factor,
    SUM(CASE WHEN status = 'Available' AND expiry_date > CURDATE() THEN units_available ELSE 0 END) AS available_units,
    SUM(CASE WHEN status = 'Reserved' THEN units_available ELSE 0 END) AS reserved_units,
    COUNT(CASE WHEN expiry_date <= DATE_ADD(CURDATE(), INTERVAL 7 DAY) AND status = 'Available' THEN 1 END) AS expiring_soon
FROM blood_bank
GROUP BY blood_type, rh_factor
ORDER BY blood_type, rh_factor;

-- 8. Active Leave Requests
CREATE OR REPLACE VIEW View_ActiveLeaveRequests AS
SELECT 
    lr.leave_id,
    CONCAT(p.first_name, ' ', p.last_name) AS employee_name,
    u.role,
    lr.leave_type,
    lr.start_date,
    lr.end_date,
    DATEDIFF(lr.end_date, lr.start_date) + 1 AS duration_days,
    lr.status,
    lr.reason,
    lr.requested_at
FROM leave_requests lr
JOIN users u ON lr.user_id = u.user_id
JOIN profiles p ON u.user_id = p.user_id
WHERE lr.status = 'Pending'
ORDER BY lr.requested_at ASC;

-- 9. Patient Feedback Analysis
CREATE OR REPLACE VIEW View_PatientFeedbackAnalysis AS
SELECT 
    feedback_category,
    COUNT(*) AS total_feedback,
    AVG(rating) AS average_rating,
    COUNT(CASE WHEN rating >= 4 THEN 1 END) AS positive_feedback,
    COUNT(CASE WHEN rating <= 2 THEN 1 END) AS negative_feedback,
    MAX(submitted_at) AS latest_feedback_date
FROM patient_feedback
GROUP BY feedback_category;

-- 10. Ambulance Fleet Status
CREATE OR REPLACE VIEW View_AmbulanceFleetStatus AS
SELECT 
    ambulance_id,
    vehicle_number,
    vehicle_type,
    current_status,
    driver_name,
    driver_contact,
    DATEDIFF(next_maintenance_due, CURDATE()) AS days_until_maintenance,
    CASE 
        WHEN next_maintenance_due < CURDATE() THEN 'OVERDUE'
        WHEN DATEDIFF(next_maintenance_due, CURDATE()) <= 7 THEN 'DUE_SOON'
        ELSE 'OK'
    END AS maintenance_status
FROM ambulance_fleet
ORDER BY current_status, next_maintenance_due;

-- 11. Medical Supplies Low Stock Alert
CREATE OR REPLACE VIEW View_LowStockSupplies AS
SELECT 
    supply_id,
    supply_name,
    category,
    current_stock,
    reorder_level,
    (reorder_level - current_stock) AS units_needed,
    supplier_name,
    last_restock_date,
    DATEDIFF(CURDATE(), last_restock_date) AS days_since_restock
FROM medical_supplies
WHERE current_stock <= reorder_level
ORDER BY (reorder_level - current_stock) DESC;

-- 12. Vaccination Schedule
CREATE OR REPLACE VIEW View_VaccinationSchedule AS
SELECT 
    vr.vaccination_id,
    vr.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    vr.vaccine_name,
    vr.dose_number,
    vr.vaccination_date AS last_dose_date,
    vr.next_dose_date,
    DATEDIFF(vr.next_dose_date, CURDATE()) AS days_until_next_dose,
    CONCAT(doc_p.first_name, ' ', doc_p.last_name) AS administered_by
FROM vaccination_records vr
JOIN patients pat ON vr.patient_id = pat.patient_id
JOIN profiles p ON pat.user_id = p.user_id
LEFT JOIN doctors d ON vr.administered_by = d.doctor_id
LEFT JOIN profiles doc_p ON d.user_id = doc_p.user_id
WHERE vr.next_dose_date IS NOT NULL AND vr.next_dose_date >= CURDATE()
ORDER BY vr.next_dose_date ASC;

-- 13. Active Announcements
CREATE OR REPLACE VIEW View_ActiveAnnouncements AS
SELECT 
    announcement_id,
    title,
    content,
    target_audience,
    priority,
    CONCAT(p.first_name, ' ', p.last_name) AS created_by_name,
    created_at,
    expiry_date,
    DATEDIFF(expiry_date, NOW()) AS days_until_expiry
FROM announcements a
JOIN users u ON a.created_by = u.user_id
JOIN profiles p ON u.user_id = p.user_id
WHERE is_active = TRUE
  AND (expiry_date IS NULL OR expiry_date > NOW())
ORDER BY priority DESC, created_at DESC;

-- 14. Comprehensive Patient Profile
CREATE OR REPLACE VIEW View_ComprehensivePatientProfile AS
SELECT 
    pat.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    p.date_of_birth,
    TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) AS age,
    p.gender,
    p.phone_number,
    pat.blood_group,
    pat.insurance_provider,
    pat.insurance_policy_no,
    COUNT(DISTINCT a.appointment_id) AS total_appointments,
    COUNT(DISTINCT pt.record_id) AS total_tests,
    COUNT(DISTINCT po.order_id) AS total_pharmacy_orders,
    MAX(a.appointment_date) AS last_appointment_date
FROM patients pat
JOIN profiles p ON pat.user_id = p.user_id
LEFT JOIN appointments a ON pat.patient_id = a.patient_id
LEFT JOIN patient_tests pt ON pat.patient_id = pt.patient_id
LEFT JOIN pharmacy_orders po ON pat.patient_id = po.patient_id
GROUP BY pat.patient_id, patient_name, p.date_of_birth, age, p.gender, 
         p.phone_number, pat.blood_group, pat.insurance_provider, pat.insurance_policy_no;

-- 15. Department Performance Metrics
CREATE OR REPLACE VIEW View_DepartmentPerformance AS
SELECT 
    dept.dept_id,
    dept.name AS department_name,
    COUNT(DISTINCT d.doctor_id) AS total_doctors,
    COUNT(DISTINCT a.appointment_id) AS total_appointments,
    COUNT(DISTINCT CASE WHEN a.status = 'Completed' THEN a.appointment_id END) AS completed_appointments,
    AVG(d.consultation_fee) AS avg_consultation_fee,
    SUM(i.total_amount) AS total_revenue
FROM departments dept
LEFT JOIN doctors d ON dept.dept_id = d.dept_id
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
LEFT JOIN invoices i ON a.appointment_id = i.appointment_id
GROUP BY dept.dept_id, dept.name;

-- 16. Room Utilization Report
CREATE OR REPLACE VIEW View_RoomUtilization AS
SELECT 
    r.room_number,
    r.type,
    r.is_available,
    COUNT(DISTINCT a.admission_id) AS total_admissions,
    SUM(DATEDIFF(COALESCE(a.discharge_date, NOW()), a.admission_date)) AS total_occupied_days,
    AVG(a.total_cost) AS avg_admission_cost,
    CONCAT(doc_p.first_name, ' ', doc_p.last_name) AS assigned_doctor
FROM rooms r
LEFT JOIN admissions a ON r.room_number = a.room_number
LEFT JOIN doctors d ON r.current_doctor_id = d.doctor_id
LEFT JOIN profiles doc_p ON d.user_id = doc_p.user_id
GROUP BY r.room_number, r.type, r.is_available, assigned_doctor;

-- 17. Staff Certification Status
CREATE OR REPLACE VIEW View_StaffCertificationStatus AS
SELECT 
    u.user_id,
    CONCAT(p.first_name, ' ', p.last_name) AS staff_name,
    u.role,
    sc.certification_name,
    sc.issuing_authority,
    sc.issue_date,
    sc.expiry_date,
    DATEDIFF(sc.expiry_date, CURDATE()) AS days_until_expiry,
    CASE 
        WHEN sc.expiry_date IS NULL THEN 'NO_EXPIRY'
        WHEN sc.expiry_date < CURDATE() THEN 'EXPIRED'
        WHEN DATEDIFF(sc.expiry_date, CURDATE()) <= 30 THEN 'EXPIRING_SOON'
        ELSE 'VALID'
    END AS certification_status
FROM users u
JOIN profiles p ON u.user_id = p.user_id
LEFT JOIN staff_certifications sc ON u.user_id = sc.user_id
WHERE u.role IN ('Doctor', 'Staff')
ORDER BY sc.expiry_date ASC;

-- 18. Pharmacy Inventory Status
CREATE OR REPLACE VIEW View_PharmacyInventoryStatus AS
SELECT 
    medicine_id,
    name AS medicine_name,
    manufacturer,
    unit_price,
    stock_quantity,
    expiry_date,
    DATEDIFF(expiry_date, CURDATE()) AS days_until_expiry,
    CASE 
        WHEN expiry_date < CURDATE() THEN 'EXPIRED'
        WHEN DATEDIFF(expiry_date, CURDATE()) <= 30 THEN 'EXPIRING_SOON'
        WHEN stock_quantity <= 10 THEN 'LOW_STOCK'
        WHEN stock_quantity = 0 THEN 'OUT_OF_STOCK'
        ELSE 'OK'
    END AS inventory_status
FROM medicines
ORDER BY expiry_date ASC, stock_quantity ASC;

-- 19. Financial Summary View
CREATE OR REPLACE VIEW View_FinancialSummary AS
SELECT 
    DATE_FORMAT(i.generated_at, '%Y-%m') AS month_year,
    COUNT(DISTINCT i.invoice_id) AS total_invoices,
    SUM(i.total_amount) AS gross_revenue,
    SUM(i.discount_amount) AS total_discounts,
    SUM(i.net_amount) AS net_revenue,
    SUM(CASE WHEN i.status = 'Paid' THEN i.net_amount ELSE 0 END) AS collected_revenue,
    SUM(CASE WHEN i.status = 'Unpaid' THEN i.net_amount ELSE 0 END) AS pending_revenue
FROM invoices i
GROUP BY month_year
ORDER BY month_year DESC;

-- 20. Doctor Workload Analysis
CREATE OR REPLACE VIEW View_DoctorWorkload AS
SELECT 
    d.doctor_id,
    CONCAT(p.first_name, ' ', p.last_name) AS doctor_name,
    dept.name AS department_name,
    COUNT(DISTINCT a.appointment_id) AS total_appointments,
    COUNT(DISTINCT CASE WHEN a.status = 'Completed' THEN a.appointment_id END) AS completed_appointments,
    COUNT(DISTINCT CASE WHEN a.status = 'Cancelled' THEN a.appointment_id END) AS cancelled_appointments,
    COUNT(DISTINCT pt.record_id) AS tests_prescribed,
    COUNT(DISTINCT pr.prescription_id) AS prescriptions_issued,
    AVG(CASE WHEN a.status = 'Completed' THEN d.consultation_fee END) AS avg_consultation_fee
FROM doctors d
JOIN profiles p ON d.user_id = p.user_id
JOIN departments dept ON d.dept_id = dept.dept_id
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
LEFT JOIN patient_tests pt ON d.doctor_id = pt.doctor_id
LEFT JOIN medical_records mr ON a.appointment_id = mr.appointment_id
LEFT JOIN prescriptions pr ON mr.record_id = pr.record_id
GROUP BY d.doctor_id, doctor_name, department_name;


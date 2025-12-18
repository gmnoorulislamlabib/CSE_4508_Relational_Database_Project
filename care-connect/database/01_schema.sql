-- Database Schema for CareConnect
-- 15 Entities, 3NF Normalized

DROP DATABASE IF EXISTS careconnect;
CREATE DATABASE careconnect;
USE careconnect;

-- 1. Users Table (Base for RBAC)
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('Admin', 'Doctor', 'Patient', 'Staff') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_email (email)
);

-- 2. Profiles Table (1:1 with Users)
CREATE TABLE profiles (
    profile_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE,
    gender ENUM('Male', 'Female', 'Other'),
    phone_number VARCHAR(20),
    address TEXT,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 3. Departments Table
CREATE TABLE departments (
    dept_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    location VARCHAR(50)
);

-- 3.1 Appointment Reasons (Domain Specific)
CREATE TABLE appointment_reasons (
    reason_id INT AUTO_INCREMENT PRIMARY KEY,
    dept_id INT NOT NULL,
    reason_text VARCHAR(100) NOT NULL,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- 3.2 Valid Specializations (Lookup)
CREATE TABLE valid_specializations (
    spec_id INT AUTO_INCREMENT PRIMARY KEY,
    dept_id INT NOT NULL,
    specialization_name VARCHAR(100) UNIQUE NOT NULL,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- 3.3 Valid Consultation Fee Tiers (Lookup)
CREATE TABLE valid_consultation_fees (
    fee_id INT AUTO_INCREMENT PRIMARY KEY,
    amount DECIMAL(10, 2) UNIQUE NOT NULL
);

-- 4. Doctors Table
CREATE TABLE doctors (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    dept_id INT NOT NULL,
    specialization VARCHAR(100),
    license_number VARCHAR(50) UNIQUE NOT NULL,
    consultation_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    joining_date DATE,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- 5. Patients Table
CREATE TABLE patients (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    blood_group VARCHAR(5),
    emergency_contact_first_name VARCHAR(50),
    emergency_contact_last_name VARCHAR(50),
    emergency_contact_phone VARCHAR(20),
    emergency_contact_email VARCHAR(100),
    emergency_contact_dob DATE,
    insurance_provider VARCHAR(100),
    insurance_policy_no VARCHAR(50),
    medical_history_summary TEXT, -- Stores aggregated history (Initial + Appointments)
    test_history_summary TEXT, -- Stores aggregated Lab Test history
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- 6. Schedules Table
CREATE TABLE schedules (
    schedule_id INT AUTO_INCREMENT PRIMARY KEY,
    doctor_id INT NOT NULL,
    day_of_week ENUM('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday') NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    room_number VARCHAR(20),
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);
ALTER TABLE schedules MODIFY day_of_week ENUM('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday') NOT NULL;

-- 7. Appointments Table
CREATE TABLE appointments (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    appointment_date DATETIME NOT NULL,
    reason TEXT,
    status ENUM('Pending_Payment', 'Scheduled', 'Confirmed', 'Completed', 'Cancelled', 'NoShow') DEFAULT 'Pending_Payment',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
    INDEX idx_appt_date (appointment_date),
    INDEX idx_status (status)
);

-- 8. Medical Records Table (JSON Feature)
CREATE TABLE medical_records (
    record_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT UNIQUE NOT NULL, -- One record per appointment usually
    diagnosis TEXT NOT NULL,
    symptoms TEXT,
    treatment_plan TEXT,
    vitals JSON, -- Stores { "bp": "120/80", "temp": "98.6", "weight": "70kg" }
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
);

-- 9. Lab Tests Catalog
CREATE TABLE lab_tests (
    test_id INT AUTO_INCREMENT PRIMARY KEY,
    test_name VARCHAR(100) UNIQUE NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL,
    reference_range VARCHAR(100),
    unit VARCHAR(20)
);

-- 10. Lab Results Table
CREATE TABLE lab_results (
    result_id INT AUTO_INCREMENT PRIMARY KEY,
    record_id INT NOT NULL,
    test_id INT NOT NULL,
    result_value VARCHAR(255) NOT NULL,
    remarks TEXT,
    test_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (record_id) REFERENCES medical_records(record_id),
    FOREIGN KEY (test_id) REFERENCES lab_tests(test_id)
);

-- 11a. Common Medical Problems Catalog (For Registration)
CREATE TABLE common_medical_problems (
    problem_id INT AUTO_INCREMENT PRIMARY KEY,
    problem_name VARCHAR(100) UNIQUE NOT NULL,
    category VARCHAR(50) -- e.g., 'Chronic', 'Allergy', 'Surgery'
);

-- 11. Medicines Inventory
CREATE TABLE medicines (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    manufacturer VARCHAR(100),
    unit_price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    expiry_date DATE,
    description TEXT
);

-- 12. Prescriptions Table
CREATE TABLE prescriptions (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    record_id INT NOT NULL,
    notes TEXT,
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (record_id) REFERENCES medical_records(record_id)
);

-- 13. Prescription Items Table
CREATE TABLE prescription_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    prescription_id INT NOT NULL,
    medicine_id INT NOT NULL,
    dosage VARCHAR(50) NOT NULL, -- e.g. "500mg"
    frequency VARCHAR(50) NOT NULL, -- e.g. "1-0-1"
    duration_days INT NOT NULL,
    FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id),
    FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id)
);

-- 14. Invoices Table
CREATE TABLE invoices (
    invoice_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT NULL, -- Nullable: For appointment-based billing
    test_record_id INT NULL, -- Nullable: For test-based billing
    total_amount DECIMAL(10, 2) NOT NULL,
    discount_amount DECIMAL(10, 2) DEFAULT 0.00,
    net_amount DECIMAL(10, 2) NOT NULL,
    status ENUM('Unpaid', 'Paid', 'Refunded') DEFAULT 'Unpaid',
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    -- FK to patient_tests will be added after patient_tests table is created
);

-- 15. Payments Table
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_method ENUM('Cash', 'Card', 'Insurance', 'Online') NOT NULL,
    transaction_ref VARCHAR(100),
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
);

-- 16. Audit Logs Table (For Requirement D)
CREATE TABLE audit_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id INT NOT NULL,
    old_value JSON,
    new_value JSON,
    performed_by INT, -- User ID
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- Foreign key to users is optional to allow logs even if user deleted, or use CASCADE carefully.
    -- Keeping it loose for now or SET NULL.
);

-- 17. Valid Medical Licenses (Whitelist)
CREATE TABLE valid_medical_licenses (
    license_number VARCHAR(50) PRIMARY KEY,
    is_registered BOOLEAN DEFAULT FALSE
);

-- 18. Hospital Rooms (Unified Table for All Types)
CREATE TABLE rooms (
    room_number VARCHAR(20) PRIMARY KEY,
    type ENUM('Consultation', 'Lab', 'Ward_NonAC', 'Ward_AC', 'ICU', 'Operation_Theater', 'Emergency') NOT NULL DEFAULT 'Consultation',
    charge_per_day DECIMAL(10, 2) DEFAULT 0.00,
    is_available BOOLEAN DEFAULT TRUE,
    current_doctor_id INT NULL -- Only relevant for Consultation/Surgery types
);

-- 19. Medical Tests Catalog
CREATE TABLE medical_tests (
    test_id INT AUTO_INCREMENT PRIMARY KEY,
    test_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    cost DECIMAL(10, 2) NOT NULL,
    estimated_duration_minutes INT DEFAULT 30,
    assigned_room_number VARCHAR(20),
    FOREIGN KEY (assigned_room_number) REFERENCES rooms(room_number) ON DELETE SET NULL
);

-- 20. Patient Test Records
CREATE TABLE patient_tests (
    record_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    test_id INT NOT NULL,
    doctor_id INT, -- Optional: Prescribing doctor (Referred By)
    status ENUM('PENDING_PAYMENT', 'SCHEDULED', 'COMPLETED', 'CANCELLED') DEFAULT 'PENDING_PAYMENT',
    payment_status ENUM('PENDING', 'PAID') DEFAULT 'PENDING',
    
    -- Scheduling
    scheduled_date TIMESTAMP NULL, -- Start Time
    scheduled_end_time TIMESTAMP NULL, -- End Time (Calculated from start + duration)
    room_number VARCHAR(20), -- Auto-assigned from medical_tests
    
    result_summary TEXT, 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (test_id) REFERENCES medical_tests(test_id),
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE SET NULL,
    FOREIGN KEY (room_number) REFERENCES rooms(room_number)
);

-- Add FK constraint from invoices to patient_tests (after patient_tests table exists)
ALTER TABLE invoices 
ADD CONSTRAINT fk_invoices_test_record 
FOREIGN KEY (test_record_id) REFERENCES patient_tests(record_id) ON DELETE CASCADE;

-- 21. Patient Admissions (Inpatient Management)
CREATE TABLE admissions (
    admission_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    room_number VARCHAR(20) NOT NULL,
    admission_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    discharge_date TIMESTAMP NULL,
    total_cost DECIMAL(10, 2) DEFAULT 0.00,
    status ENUM('Admitted', 'Discharged') DEFAULT 'Admitted',
    payment_status ENUM('Pending', 'Paid') DEFAULT 'Pending',
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (room_number) REFERENCES rooms(room_number)
);

-- Note: Invoices table FK for admission will be handled via link or generic
ALTER TABLE invoices ADD COLUMN admission_id INT NULL;
ALTER TABLE invoices ADD CONSTRAINT fk_invoices_admission FOREIGN KEY (admission_id) REFERENCES admissions(admission_id) ON DELETE CASCADE;

-- 22. Pharmacy Orders Table
CREATE TABLE IF NOT EXISTS pharmacy_orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status ENUM('Pending_Payment', 'Completed', 'Cancelled') DEFAULT 'Pending_Payment',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

-- 23. Pharmacy Order Items Table
CREATE TABLE IF NOT EXISTS pharmacy_order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    medicine_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES pharmacy_orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id)
);

-- Link Invoice to Pharmacy Order
ALTER TABLE invoices ADD COLUMN pharmacy_order_id INT NULL;
ALTER TABLE invoices ADD CONSTRAINT fk_invoices_pharmacy_order FOREIGN KEY (pharmacy_order_id) REFERENCES pharmacy_orders(order_id);

-- 24. Hospital Expenses Table (For Net Revenue Calculation)
CREATE TABLE IF NOT EXISTS hospital_expenses (
    expense_id INT AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(50) NOT NULL, -- e.g. 'Pharmacy_Restock', 'Maintenance', 'Salaries'
    amount DECIMAL(10, 2) NOT NULL,
    description TEXT,
    expense_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    performed_by INT -- User ID of admin who recorded it
);

-- 25. Financial Reports (Pre-calculated View Table)
CREATE TABLE IF NOT EXISTS financial_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    report_type ENUM('Yearly', 'Monthly', 'Weekly') NOT NULL,
    period_label VARCHAR(50) NOT NULL, -- '2025', '2025-01', '2025-W01'
    total_revenue DECIMAL(15, 2) DEFAULT 0.00,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_report (report_type, period_label)
);

-- 26. Hospital Equipment Inventory
CREATE TABLE IF NOT EXISTS equipment_inventory (
    equipment_id INT AUTO_INCREMENT PRIMARY KEY,
    equipment_name VARCHAR(100) NOT NULL,
    equipment_type VARCHAR(50) NOT NULL,
    manufacturer VARCHAR(100),
    model_number VARCHAR(50),
    serial_number VARCHAR(100) UNIQUE,
    purchase_date DATE,
    warranty_expiry DATE,
    maintenance_schedule VARCHAR(50),
    current_status ENUM('Operational', 'Under_Maintenance', 'Faulty', 'Decommissioned') DEFAULT 'Operational',
    assigned_dept_id INT,
    assigned_room VARCHAR(20),
    acquisition_cost DECIMAL(12, 2),
    FOREIGN KEY (assigned_dept_id) REFERENCES departments(dept_id),
    FOREIGN KEY (assigned_room) REFERENCES rooms(room_number)
);

-- 27. Equipment Maintenance Log
CREATE TABLE IF NOT EXISTS equipment_maintenance_log (
    maintenance_id INT AUTO_INCREMENT PRIMARY KEY,
    equipment_id INT NOT NULL,
    maintenance_type ENUM('Routine', 'Repair', 'Calibration', 'Emergency') NOT NULL,
    maintenance_date DATETIME NOT NULL,
    performed_by VARCHAR(100),
    service_provider VARCHAR(100),
    cost DECIMAL(10, 2),
    description TEXT,
    next_maintenance_date DATE,
    FOREIGN KEY (equipment_id) REFERENCES equipment_inventory(equipment_id)
);

-- 28. Staff Attendance Records
CREATE TABLE IF NOT EXISTS staff_attendance (
    attendance_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    check_in_time DATETIME NOT NULL,
    check_out_time DATETIME,
    attendance_date DATE NOT NULL,
    status ENUM('Present', 'Absent', 'Late', 'Half_Day', 'On_Leave') DEFAULT 'Present',
    remarks TEXT,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_attendance_date (attendance_date)
);

-- 29. Leave Requests
CREATE TABLE IF NOT EXISTS leave_requests (
    leave_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    leave_type ENUM('Sick', 'Casual', 'Earned', 'Maternity', 'Paternity', 'Emergency') NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    status ENUM('Pending', 'Approved', 'Rejected', 'Cancelled') DEFAULT 'Pending',
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_by INT,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (approved_by) REFERENCES users(user_id)
);

-- 30. Staff Certifications
CREATE TABLE IF NOT EXISTS staff_certifications (
    certification_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    certification_name VARCHAR(100) NOT NULL,
    issuing_authority VARCHAR(100),
    issue_date DATE,
    expiry_date DATE,
    certificate_number VARCHAR(50),
    verification_url VARCHAR(255),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- 31. Patient Feedback
CREATE TABLE IF NOT EXISTS patient_feedback (
    feedback_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    appointment_id INT,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    feedback_category ENUM('Doctor', 'Service', 'Facility', 'Billing', 'Staff', 'General') NOT NULL,
    comments TEXT,
    is_anonymous BOOLEAN DEFAULT FALSE,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
);

-- 32. Hospital Announcements
CREATE TABLE IF NOT EXISTS announcements (
    announcement_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    target_audience ENUM('All', 'Doctors', 'Patients', 'Staff', 'Admin') DEFAULT 'All',
    priority ENUM('Low', 'Medium', 'High', 'Urgent') DEFAULT 'Medium',
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiry_date DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (created_by) REFERENCES users(user_id)
);

-- 33. Medical Supplies Catalog
CREATE TABLE IF NOT EXISTS medical_supplies (
    supply_id INT AUTO_INCREMENT PRIMARY KEY,
    supply_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit_of_measure VARCHAR(20),
    reorder_level INT DEFAULT 50,
    current_stock INT DEFAULT 0,
    unit_cost DECIMAL(10, 2),
    supplier_name VARCHAR(100),
    last_restock_date DATE,
    expiry_tracking BOOLEAN DEFAULT FALSE
);

-- 34. Supply Usage Log
CREATE TABLE IF NOT EXISTS supply_usage_log (
    usage_id INT AUTO_INCREMENT PRIMARY KEY,
    supply_id INT NOT NULL,
    quantity_used INT NOT NULL,
    used_by_dept_id INT,
    used_for_patient_id INT,
    usage_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    recorded_by INT,
    remarks TEXT,
    FOREIGN KEY (supply_id) REFERENCES medical_supplies(supply_id),
    FOREIGN KEY (used_by_dept_id) REFERENCES departments(dept_id),
    FOREIGN KEY (used_for_patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (recorded_by) REFERENCES users(user_id)
);

-- 35. Blood Bank Inventory
CREATE TABLE IF NOT EXISTS blood_bank (
    blood_id INT AUTO_INCREMENT PRIMARY KEY,
    blood_type VARCHAR(5) NOT NULL,
    rh_factor ENUM('Positive', 'Negative') NOT NULL,
    units_available INT DEFAULT 0,
    collection_date DATE,
    expiry_date DATE NOT NULL,
    donor_id VARCHAR(50),
    storage_location VARCHAR(50),
    status ENUM('Available', 'Reserved', 'Used', 'Expired', 'Discarded') DEFAULT 'Available',
    INDEX idx_blood_type (blood_type, rh_factor)
);

-- 36. Blood Transfusion Records
CREATE TABLE IF NOT EXISTS blood_transfusions (
    transfusion_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    blood_id INT NOT NULL,
    doctor_id INT NOT NULL,
    transfusion_date DATETIME NOT NULL,
    units_transfused DECIMAL(5, 2) NOT NULL,
    reaction_observed BOOLEAN DEFAULT FALSE,
    reaction_notes TEXT,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (blood_id) REFERENCES blood_bank(blood_id),
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

-- 37. Emergency Contacts Registry
CREATE TABLE IF NOT EXISTS emergency_contacts_registry (
    contact_id INT AUTO_INCREMENT PRIMARY KEY,
    contact_name VARCHAR(100) NOT NULL,
    relationship VARCHAR(50),
    phone_number VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    address TEXT,
    notes TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 38. Ambulance Fleet Management
CREATE TABLE IF NOT EXISTS ambulance_fleet (
    ambulance_id INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_number VARCHAR(50) UNIQUE NOT NULL,
    vehicle_type ENUM('Basic', 'Advanced', 'Air_Ambulance') NOT NULL,
    registration_number VARCHAR(50) UNIQUE,
    driver_name VARCHAR(100),
    driver_contact VARCHAR(20),
    current_status ENUM('Available', 'On_Duty', 'Under_Maintenance', 'Out_of_Service') DEFAULT 'Available',
    last_maintenance_date DATE,
    next_maintenance_due DATE,
    equipment_list TEXT
);

-- 39. Ambulance Service Logs
CREATE TABLE IF NOT EXISTS ambulance_service_logs (
    service_id INT AUTO_INCREMENT PRIMARY KEY,
    ambulance_id INT NOT NULL,
    patient_id INT,
    pickup_location TEXT NOT NULL,
    dropoff_location TEXT NOT NULL,
    service_date DATETIME NOT NULL,
    completion_time DATETIME,
    distance_km DECIMAL(8, 2),
    charge_amount DECIMAL(10, 2),
    emergency_type VARCHAR(100),
    FOREIGN KEY (ambulance_id) REFERENCES ambulance_fleet(ambulance_id),
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

-- 40. Vaccination Records
CREATE TABLE IF NOT EXISTS vaccination_records (
    vaccination_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    vaccine_name VARCHAR(100) NOT NULL,
    dose_number INT,
    vaccination_date DATE NOT NULL,
    administered_by INT,
    batch_number VARCHAR(50),
    manufacturer VARCHAR(100),
    site_of_injection VARCHAR(50),
    next_dose_date DATE,
    adverse_reaction TEXT,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (administered_by) REFERENCES doctors(doctor_id)
);




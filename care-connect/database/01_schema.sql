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




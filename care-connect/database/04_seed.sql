-- Seed Data for CareConnect (Bangladesh Context)

USE careconnect;

-- Users (1 Admin, 2 Doctors, 2 Patients)
-- Passwords are 'password123' placeholder
INSERT INTO users (email, password_hash, role) VALUES 
('admin@careconnect.bd', 'admin123', 'Admin'),
('dr.rahman@careconnect.bd', 'doctor123', 'Doctor'),
('dr.nasreen@careconnect.bd', 'doctor123', 'Doctor'),
('rahim.mia@careconnect.bd', 'patient123', 'Patient'),
('fatema.begum@careconnect.bd', 'patient123', 'Patient');

-- Profiles
INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(1, 'Tanvir', 'Ahmed', '01711000001', 'Male', '1980-01-01', 'Uttara, Dhaka'),
(2, 'Mahbubur', 'Rahman', '01711000002', 'Male', '1975-05-20', 'Dhanmondi, Dhaka'),
(3, 'Nasreen', 'Sultana', '01811000003', 'Female', '1982-08-15', 'Gulshan, Dhaka'),
(4, 'Rahim', 'Mia', '01911000004', 'Male', '1995-03-10', 'Mirpur, Dhaka'),
(5, 'Fatema', 'Begum', '01611000005', 'Female', '2000-07-25', 'Agrabad, Chattogram');

-- Valid Medical Licenses (Seed First for Triggers)
INSERT INTO valid_medical_licenses (license_number, is_registered) VALUES
('BMDC-A-12345', FALSE), -- Will be taken by Dr. Rahman
('BMDC-A-67890', FALSE), -- Will be taken by Dr. Nasreen
('BMDC-A-99887', FALSE), -- Will be taken by Dr. Sara
('BMDC-A-55443', FALSE), -- Will be taken by Dr. Fahim
('BMDC-A-11111', FALSE), -- Available
('BMDC-A-22222', FALSE), -- Available
('BMDC-A-33333', FALSE); -- Available


-- Hospital Rooms (Unified)
INSERT INTO rooms (room_number, type, charge_per_day, is_available) VALUES
('Rm-101', 'Consultation', 0, TRUE),
('Rm-205', 'Consultation', 0, TRUE),
('Rm-301', 'Consultation', 0, TRUE),
('Rm-402', 'Consultation', 0, TRUE),
('Rm-505', 'Consultation', 0, TRUE),
('Rm-601', 'Emergency', 500, TRUE),
('Lab-001', 'Lab', 0, TRUE),
('Lab-002', 'Lab', 0, TRUE),
('XRay-01', 'Lab', 0, TRUE),
('MRI-01', 'Lab', 0, TRUE),
-- New Inpatient Rooms
('Ward-101', 'Ward_NonAC', 1500.00, TRUE),
('Ward-102', 'Ward_NonAC', 1500.00, TRUE),
('Ward-201', 'Ward_AC', 3000.00, TRUE),
('Ward-202', 'Ward_AC', 3000.00, TRUE),
('ICU-01', 'ICU', 10000.00, TRUE),
('ICU-02', 'ICU', 10000.00, TRUE),
('OT-01', 'Operation_Theater', 15000.00, TRUE),
('OT-02', 'Operation_Theater', 15000.00, TRUE);

-- Medical Tests (Moved after rooms to reference them)
INSERT INTO medical_tests (test_name, description, cost, estimated_duration_minutes, assigned_room_number) VALUES
('CBC (Complete Blood Count)', 'Evaluates overall health and detects a wide range of disorders.', 500.00, 2, 'Lab-001'),
('Chest X-Ray', 'Produces images of the heart, lungs, airways, blood vessels and the bones of the spine and chest.', 800.00, 3, 'XRay-01'),
('MRI Scan', 'Magnetic Resonance Imaging using strong magnetic fields.', 5000.00, 5, 'MRI-01'),
('Lipid Profile', 'Measures cholesterol and other fats in blood.', 1200.00, 2, 'Lab-001'),
('Urinalysis', 'Test of urine.', 300.00, 1, 'Lab-002');

-- Departments (Must be seeded before Specializations now)
INSERT INTO departments (name, description, location) VALUES 
('Cardiology', 'Heart related diseases', 'Building A, Level 3 (Dhanmondi Branch)'),
('Orthopedics', 'Bone and joint care', 'Building B, Level 2 (Dhanmondi Branch)'),
('General Medicine', 'General health checkup', 'Building A, Level 1 (Dhanmondi Branch)'),
('Pediatrics', 'Child healthcare', 'Building B, Level 1'),
('Dermatology', 'Skin care', 'Building A, Level 4'),
('Neurology', 'Nervous system', 'Building C, Level 2'),
('Gynecology', 'Womens health', 'Building C, Level 3'),
('Psychiatry', 'Mental health', 'Building C, Level 4');

-- Valid Specializations (Lookup)
INSERT INTO valid_specializations (dept_id, specialization_name) VALUES
(1, 'Cardiologist'),
(2, 'Orthopedic Surgeon'),
(3, 'General Practitioner'),
(4, 'Pediatrician'),
(5, 'Dermatologist'),
(6, 'Neurologist'),
(7, 'Gynecologist'),
(8, 'Psychiatrist');

-- Valid Consultation Fees (Lookup) - Range 500 to 2000
INSERT INTO valid_consultation_fees (amount) VALUES
(500.00),
(800.00),
(1000.00),
(1200.00),
(1500.00),
(1800.00),
(2000.00);

-- Valid Reasons for Appointments
INSERT INTO appointment_reasons (dept_id, reason_text) VALUES 
(1, 'Chest Pain'), (1, 'High Blood Pressure'), (1, 'Heart Palpitations'), (1, 'Post-Surgery Checkup'),
(2, 'Joint Pain'), (2, 'Fracture Consultation'), (2, 'Back Pain'), (2, 'Arthritis Checkup'),
(3, 'Fever/Flu'), (3, 'General Weakness'), (3, 'Routine Checkup'), (3, 'Vaccination'),
(4, 'Childhood Fever'), (4, 'Vaccination Schedule'), (4, 'Growth Monitoring'),
(5, 'Skin Rash'), (5, 'Acne Treatment'), (5, 'Hair Loss'), (5, 'Burn Injury'),
(6, 'Headache/Migraine'), (6, 'Numbness'), (6, 'Seizures'),
(7, 'Pregnancy Checkup'), (7, 'Menstrual Irregularities'), (7, 'PCOS Consultation'),
(8, 'Anxiety'), (8, 'Depression'), (8, 'Stress Management');

-- Doctors
-- Fees in BDT
INSERT INTO doctors (user_id, dept_id, specialization, license_number, consultation_fee, joining_date) VALUES
(2, 1, 'Cardiologist', 'BMDC-A-12345', 1500.00, '2015-01-01'),
(3, 2, 'Orthopedic Surgeon', 'BMDC-A-67890', 2000.00, '2018-06-15');

-- Patients
-- Patients
INSERT INTO patients (user_id, blood_group, emergency_contact_first_name, emergency_contact_last_name, emergency_contact_phone, emergency_contact_email, emergency_contact_dob, insurance_provider) VALUES
(4, 'O+', 'Karim', 'Mia', '01911000999', 'karim.mia@example.com', '1990-01-01', 'MetLife Bangladesh'),
(5, 'A-', 'Abdul', 'Malek', '01611000888', 'abdul.malek@example.com', '1965-05-15', 'Pragati Life Insurance');

-- Additional SEED DATA (More Users, Profiles, Doctors, Patients) --

-- 6. New Doctor (Pediatrician)
INSERT INTO users (email, password_hash, role) VALUES ('dr.sara@careconnect.bd', 'hash_doc3', 'Doctor');
INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(6, 'Sara', 'Khan', '01555000001', 'Female', '1985-11-20', 'Banani, Dhaka');
INSERT INTO doctors (user_id, dept_id, specialization, license_number, consultation_fee, joining_date) VALUES
(6, 3, 'Pediatrician', 'BMDC-A-99887', 1200.00, '2020-02-01');
INSERT INTO schedules (doctor_id, day_of_week, start_time, end_time, room_number) VALUES
(3, 'Sunday', '10:00:00', '14:00:00', 'Rm-101'),
(3, 'Tuesday', '10:00:00', '14:00:00', 'Rm-101');

-- 7. New Patient (Child)
INSERT INTO users (email, password_hash, role) VALUES ('tina.baby@careconnect.bd', 'hash_pat3', 'Patient');
INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(7, 'Tina', 'Das', '01700000007', 'Female', '2015-06-15', 'Mohakhali, Dhaka');
INSERT INTO patients (user_id, blood_group, emergency_contact_first_name, emergency_contact_last_name, emergency_contact_phone, emergency_contact_email, emergency_contact_dob, insurance_provider) VALUES
(7, 'B+', 'Sumi', 'Das', '01700000000', 'sumi.das@example.com', '1990-03-10', 'None');

-- 8. New Patient (Senior)
INSERT INTO users (email, password_hash, role) VALUES ('kamal.hossain@careconnect.bd', 'hash_pat4', 'Patient');
INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(8, 'Kamal', 'Hossain', '01888000008', 'Male', '1950-12-05', 'Badda, Dhaka');
INSERT INTO patients (user_id, blood_group, emergency_contact_first_name, emergency_contact_last_name, emergency_contact_phone, emergency_contact_email, emergency_contact_dob, insurance_provider) VALUES
(8, 'AB+', 'Jamal', 'Hossain', '01888000009', 'jamal.h@example.com', '1980-07-22', 'Delta Life Insurance');

-- 9. New Doctor (Dermatologist) - Department 5 (Dermatology) is now seeded above.
-- INSERT INTO departments (name, description, location) VALUES ('Dermatology', 'Skin care', 'Building A, Level 4');
-- Appointment reasons are also seeded above.
-- INSERT INTO appointment_reasons (dept_id, reason_text) VALUES 
-- (4, 'Skin Rash'), (4, 'Acne Treatment'), (4, 'Hair Loss'), (4, 'Burn Injury');

INSERT INTO users (email, password_hash, role) VALUES ('dr.fahim@careconnect.bd', 'hash_doc4', 'Doctor');
INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(9, 'Fahim', 'Uddin', '01333000009', 'Male', '1979-09-09', 'Lalmatia, Dhaka');
INSERT INTO doctors (user_id, dept_id, specialization, license_number, consultation_fee, joining_date) VALUES
(9, 4, 'Dermatologist', 'BMDC-A-55443', 1800.00, '2016-01-01');
INSERT INTO schedules (doctor_id, day_of_week, start_time, end_time, room_number) VALUES
(4, 'Monday', '17:00:00', '21:00:00', 'Rm-402'),
(4, 'Thursday', '17:00:00', '21:00:00', 'Rm-402');

-- Schedules
-- Timings 
INSERT INTO schedules (doctor_id, day_of_week, start_time, end_time, room_number) VALUES
(1, 'Monday', '16:00:00', '20:00:00', 'Rm-301'), -- Evening practice common in BD
(1, 'Wednesday', '16:00:00', '20:00:00', 'Rm-301'),
(2, 'Sunday', '15:00:00', '19:00:00', 'Rm-205'), -- Week starts Sunday in BD (or mixed corporate/gov). Sunday is a working day.
(2, 'Tuesday', '15:00:00', '19:00:00', 'Rm-205'),
(2, 'Thursday', '15:00:00', '19:00:00', 'Rm-205');


-- Lab Tests
-- Prices in BDT
INSERT INTO lab_tests (test_name, base_price, unit) VALUES
('Complete Blood Count (CBC)', 600.00, 'cells/mcL'),
('X-Ray Chest P/A View', 800.00, 'image'),
('Lipid Profile', 1500.00, 'mg/dL'),
('Dengue NS1 Antigen', 1200.00, 'positive/negative');

-- 11a. Seed Common Medical Problems
INSERT INTO common_medical_problems (problem_name, category) VALUES
('Diabetes Type 2', 'Chronic'),
('Hypertension', 'Chronic'),
('Asthma', 'Respiratory'),
('Migraine', 'Neurological'),
('Seasonal Allergies', 'Allergy'),
('Gastritis', 'Gastrointestinal'),
('Previous Surgery', 'Surgery'),
('None', 'General');

-- Medicines
-- Prices in BDT
INSERT INTO medicines (name, manufacturer, unit_price, stock_quantity) VALUES
('Napa Extra', 'Beximco Pharma', 2.50, 5000),
('Seclo 20mg', 'Square Pharma', 7.00, 3000),
('Monas 10', 'Acme', 18.00, 2000),
('Sergel 20', 'Healthcare', 8.00, 3000);

-- Appointments (Some generated)
-- Note: In a real flow, 'BookAppointment' proc would be called.
-- Appointments (Some generated)
-- Note: In a real flow, 'BookAppointment' proc would be called.
INSERT INTO appointments (patient_id, doctor_id, appointment_date, status, reason) VALUES
(1, 1, DATE_ADD(NOW(), INTERVAL 1 DAY), 'Scheduled', 'Chest pain heavily felt at night'),
(2, 2, DATE_ADD(NOW(), INTERVAL 2 DAY), 'Scheduled', 'Knee pain while praying');

-- Invoices & Payments for Initial Scheduled Appointments (IDs 1 & 2)
-- Using Doc 1 (Cardio) Fee: 1500, Doc 2 (Ortho) Fee: 2000
INSERT INTO invoices (appointment_id, total_amount, net_amount, status) VALUES
(1, 1500.00, 1500.00, 'Paid'),
(2, 2000.00, 2000.00, 'Paid');

INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES 
(1, 1500.00, 'Online', DATE_ADD(NOW(), INTERVAL 1 DAY)), -- Future payment for future appt?? Let's say paid NOW
(2, 2000.00, 'Card', DATE_ADD(NOW(), INTERVAL 2 DAY));

-- Completed Appointment for History
INSERT INTO appointments (patient_id, doctor_id, appointment_date, status, reason) VALUES
(1, 1, DATE_SUB(NOW(), INTERVAL 5 DAY), 'Completed', 'Routine Checkup');

-- Medical Record for Completed Appt
INSERT INTO medical_records (appointment_id, diagnosis, symptoms, vitals) VALUES
(3, 'Hypertension', 'Headache, High BP', '{"bp": "140/90", "heart_rate": "82", "temp": "98.4"}');

-- Prescriptions
INSERT INTO prescriptions (record_id, notes) VALUES (1, 'Avoid heavy meal at night. Walk 30 mins daily.');

-- Prescription Items
INSERT INTO prescription_items (prescription_id, medicine_id, dosage, frequency, duration_days) VALUES
(1, 1, '500mg', '1-0-1', 5), -- Napa
(1, 2, '20mg', '1-0-0', 15); -- Seclo

-- Invoice for Completed Appt
-- Manual calculation: Doc Fee 1500 + Meds ((2.5*15) + (7*15) = 142.5) ~ 1642.5
-- NOTE: invoice_id will be 3
INSERT INTO invoices (appointment_id, total_amount, net_amount, status) VALUES
(3, 1642.50, 1642.50, 'Paid');

-- Add Payment for Completed Appt to reflect in Transaction Tracker
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES 
(3, 1642.50, 'Cash', DATE_SUB(NOW(), INTERVAL 5 DAY));

-- TEST: Appointment for TODAY (To verify Dashboard Logic)
INSERT INTO appointments (patient_id, doctor_id, appointment_date, status, reason) VALUES
(2, 3, NOW(), 'Scheduled', 'Sudden Fever - Today');

-- Invoice & Payment for Today's Appt (ID 4)
-- Doc 3 (Orthopedic) Fee is actually 2000 (wait, ID 3 is Nasreen, Ortho).
INSERT INTO invoices (appointment_id, total_amount, net_amount, status) VALUES
(4, 2000.00, 2000.00, 'Paid');

INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES 
(4, 2000.00, 'Cash', NOW());


-- 19. Seed Valid Licenses and Rooms (Before Doctors insert ideally, but here for DB Setup flow)
-- We need to ensure the existing seeded doctors have valid licenses in this table first, or disable check temporarily.
-- However, triggers fire on INSERT. So we should insert these license BEFORE inserting doctors.
-- Moving this section to the top of 04_seed.sql is cleaner, or I will use INSERT IGNORE if already exists.

-- Actually, since 04_seed runs sequentially, I should put these inserts AT THE TOP of the file.
-- But since I am editing the end here, I will depend on the fact that existing doctors are inserted ABOVE.
-- WAIT. If I add the Trigger now, running db:setup will FAIL on the Doctor Inserts above because the license table is empty at that point.
-- I MUST seed the licenses BEFORE the doctors.

-- I will use a separate edit to Move/Insert licenses at the top.
-- This edit will just add the table data for NEW/Future uses at the end for now, but I will make a separate edit to fix the order.



-- 20. Receptionist User
INSERT INTO users (email, password_hash, role) VALUES ('reception@careconnect.bd', 'reception123', 'Staff');
INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(10, 'Reception', 'Desk', '01711111111', 'Other', '2000-01-01', 'Hospital Front Desk');

-- =========================================================
-- EXTENDED SEED DATA FOR TESTING (APPENDED)
-- =========================================================

-- 21. New Doctor: Dr. Ayesha (Gynecology)
INSERT INTO users (email, password_hash, role) VALUES ('dr.ayesha@careconnect.bd', 'doctor123', 'Doctor'); -- ID 11
INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(11, 'Ayesha', 'Siddiqa', '01711111112', 'Female', '1983-04-12', 'Mirpur DOHS, Dhaka');
INSERT INTO doctors (user_id, dept_id, specialization, license_number, consultation_fee, joining_date) VALUES
(11, 7, 'Gynecologist', 'BMDC-A-11111', 1500.00, '2019-01-01');
INSERT INTO schedules (doctor_id, day_of_week, start_time, end_time, room_number) VALUES
(5, 'Sunday', '10:00:00', '13:00:00', 'Rm-505'),
(5, 'Tuesday', '10:00:00', '13:00:00', 'Rm-505');

-- 22. New Doctor: Dr. Kamal (General Medicine)
INSERT INTO users (email, password_hash, role) VALUES ('dr.kamal@careconnect.bd', 'doctor123', 'Doctor'); -- ID 12
INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(12, 'Kamal', 'Uddin', '01711111113', 'Male', '1978-11-30', 'Bashundhara, Dhaka');
INSERT INTO doctors (user_id, dept_id, specialization, license_number, consultation_fee, joining_date) VALUES
(12, 3, 'General Practitioner', 'BMDC-A-22222', 800.00, '2010-05-15');
INSERT INTO schedules (doctor_id, day_of_week, start_time, end_time, room_number) VALUES
(6, 'Saturday', '16:00:00', '21:00:00', 'Rm-205'),
(6, 'Monday', '16:00:00', '21:00:00', 'Rm-205');

-- 23. New Doctor: Dr. Rafiq (Neurology)
INSERT INTO users (email, password_hash, role) VALUES ('dr.rafiq@careconnect.bd', 'doctor123', 'Doctor'); -- ID 13
INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(13, 'Rafiq', 'Islam', '01711111114', 'Male', '1975-02-20', 'Uttara, Dhaka');
INSERT INTO doctors (user_id, dept_id, specialization, license_number, consultation_fee, joining_date) VALUES
(13, 6, 'Neurologist', 'BMDC-A-33333', 2000.00, '2015-08-01');
INSERT INTO schedules (doctor_id, day_of_week, start_time, end_time, room_number) VALUES
(7, 'Wednesday', '18:00:00', '21:00:00', 'Rm-301');

-- 24. New Patients
INSERT INTO users (email, password_hash, role) VALUES 
('salma.jahan@careconnect.bd', 'patient123', 'Patient'), -- ID 14
('james.bond@careconnect.bd', 'patient123', 'Patient'), -- ID 15
('anis.haq@careconnect.bd', 'patient123', 'Patient'); -- ID 16

INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(14, 'Salma', 'Jahan', '01999999991', 'Female', '1992-05-10', 'Farmgate, Dhaka'),
(15, 'James', 'Bond', '01999999992', 'Male', '1980-01-01', 'Baridhara, Dhaka'),
(16, 'Anisul', 'Haque', '01999999993', 'Male', '1960-12-16', 'Gulshan 2, Dhaka');

INSERT INTO patients (user_id, blood_group, emergency_contact_first_name, emergency_contact_last_name, emergency_contact_phone) VALUES
(14, 'O+', 'Mother', 'Jahan', '01900000001'),
(15, 'AB-', 'M', 'Chief', '01900000002'),
(16, 'B+', 'Wife', 'Haq', '01900000003');

-- =========================================================
-- HISTORICAL FINANCIAL DATA (For Analytics Testing)
-- =========================================================

-- Month 1 (4 Months ago): ~5000 revenue
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(100, 1, 1, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Old Checkup 1');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(100, 100, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES 
(100, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH));

-- Month 2 (3 Months ago): ~8000 revenue
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(101, 2, 2, DATE_SUB(NOW(), INTERVAL 3 MONTH), 'Completed', 'Bone Fracture Followup');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(101, 101, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 MONTH));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES 
(101, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 3 MONTH));

INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(102, 3, 5, DATE_SUB(NOW(), INTERVAL 3 MONTH), 'Completed', 'Pregnancy Check'); -- Dr. Ayesha
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(102, 102, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 MONTH));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES 
(102, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 3 MONTH));


-- Month 3 (Last Month): ~12000 revenue
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(103, 4, 6, DATE_SUB(NOW(), INTERVAL 1 MONTH), 'Completed', 'Viral Fever'); -- Dr. Kamal
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(103, 103, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 1 MONTH));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES 
(103, 800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 1 MONTH));

INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(104, 5, 7, DATE_SUB(NOW(), INTERVAL 28 DAY), 'Completed', 'Migraine'); -- Dr. Rafiq
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(104, 104, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 28 DAY));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES 
(104, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 28 DAY));

-- Month 4 (Current Month/Week): Mixed
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(105, 1, 1, NOW(), 'Scheduled', 'Follow up');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(105, 105, 1500.00, 1500.00, 'Paid', NOW());
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES 
(105, 1500.00, 'Online', NOW());

-- Lab Tests
INSERT INTO patient_tests (patient_id, test_id, record_id, doctor_id, payment_status, status) VALUES
(1, 1, 500, 1, 'PAID', 'COMPLETED');

-- Invoice for the test (Manual ID 500)
INSERT INTO invoices (invoice_id, test_record_id, total_amount, net_amount, status, generated_at) VALUES
(500, 500, 500.00, 500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 2 DAY));

-- Payment for test
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES
(500, 500.00, 'Online', DATE_SUB(NOW(), INTERVAL 2 DAY));


-- =========================================================
-- COMPREHENSIVE SEED DATA
-- Ensures EVERY Doctor has income and EVERY Patient has activity
-- =========================================================

-- DOCTORS LIST (For Reference):
-- 1: Cardiologist (Old)
-- 2: Orthopedic (Old)
-- 3: Pediatrician (Seed)
-- 4: Dermatologist (Seed)
-- 5: Dr. Ayesha (Gyne - New)
-- 6: Dr. Kamal (Gen Med - New)
-- 7: Dr. Rafiq (Neuro - New)

-- PATIENTS LIST (For Reference):
-- 1: Karim
-- 2: Abdul
-- 3: Tina
-- 4: Kamal (Senior)
-- 5: Salma
-- 6: James
-- 7: Anisul

-- Generating IDs starting from 200 to avoid conflicts

-- =========================================================
-- DOCTOR ACTIVITY (Appointments & Revenue)
-- =========================================================

-- DOC 1 (Cardio): High Volume
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(200, 1, 1, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Checkup 1'),
(201, 2, 1, DATE_SUB(NOW(), INTERVAL 3 MONTH), 'Completed', 'Checkup 2'),
(202, 5, 1, DATE_SUB(NOW(), INTERVAL 1 MONTH), 'Completed', 'Chest Pain');

INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(200, 200, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(201, 201, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 MONTH)),
(202, 202, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 1 MONTH));

-- DOC 2 (Ortho): High Fee
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(203, 3, 2, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Leg Pain'),
(204, 6, 2, DATE_SUB(NOW(), INTERVAL 2 WEEK), 'Completed', 'Sports Injury');

INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(203, 203, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(204, 204, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 2 WEEK));

-- DOC 3 (Pediatrics): Low Fee, High Volume
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(205, 3, 3, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Vaccine'),
(206, 3, 3, DATE_SUB(NOW(), INTERVAL 3 MONTH), 'Completed', 'Fever'),
(207, 7, 3, DATE_SUB(NOW(), INTERVAL 1 WEEK), 'Completed', 'Cold');

INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(205, 205, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(206, 206, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 MONTH)),
(207, 207, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 1 WEEK));

-- DOC 4 (Dermatology): Medium
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(208, 1, 4, DATE_SUB(NOW(), INTERVAL 2 MONTH), 'Completed', 'Rash'),
(209, 5, 4, DATE_SUB(NOW(), INTERVAL 10 DAY), 'Completed', 'Acne');

INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(208, 208, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 2 MONTH)),
(209, 209, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 10 DAY));

-- DOC 5 (Gynecology): Ayesha
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(210, 5, 5, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Regular Checkup'),
(211, 5, 5, DATE_SUB(NOW(), INTERVAL 2 MONTH), 'Completed', 'Followup'),
(212, 3, 5, DATE_SUB(NOW(), INTERVAL 5 DAY), 'Completed', 'Discussion'); -- Tina (Mother)

INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(210, 210, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(211, 211, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 2 MONTH)),
(212, 212, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 DAY));

-- DOC 6 (Gen Med): Kamal (Low fee, Many patients)
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(213, 2, 6, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Weakness'),
(214, 4, 6, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Routine'),
(215, 6, 6, DATE_SUB(NOW(), INTERVAL 3 MONTH), 'Completed', 'Headache'),
(216, 7, 6, DATE_SUB(NOW(), INTERVAL 2 MONTH), 'Completed', 'Fever');

INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(213, 213, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(214, 214, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(215, 215, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 MONTH)),
(216, 216, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 2 MONTH));

-- DOC 7 (Neuro): Rafiq
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(217, 4, 7, DATE_SUB(NOW(), INTERVAL 1 MONTH), 'Completed', 'Migraine'),
(218, 1, 7, DATE_SUB(NOW(), INTERVAL 3 DAY), 'Completed', 'Numbness');

INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(217, 217, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 1 MONTH)),
(218, 218, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 DAY));


-- =========================================================
-- PATIENT ACTIVITY (Lab Tests)
-- =========================================================
-- Ensuring Patients 2,4,6,7 have tests (1,3,5 already active in appts)

-- Patient 2 (Abdul) - XRay
INSERT INTO patient_tests (patient_id, test_id, record_id, doctor_id, payment_status, status) VALUES (2, 2, 600, 2, 'PAID', 'COMPLETED');
INSERT INTO invoices (invoice_id, test_record_id, total_amount, net_amount, status, generated_at) VALUES (600, 600, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 2 MONTH));

-- Patient 4 (Kamal) - Lipid Profile
INSERT INTO patient_tests (patient_id, test_id, record_id, doctor_id, payment_status, status) VALUES (4, 3, 601, 1, 'PAID', 'COMPLETED');
INSERT INTO invoices (invoice_id, test_record_id, total_amount, net_amount, status, generated_at) VALUES (601, 601, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 1 MONTH));

-- Patient 6 (James) - Dengue
INSERT INTO patient_tests (patient_id, test_id, record_id, doctor_id, payment_status, status) VALUES (6, 4, 602, 6, 'PAID', 'COMPLETED');
INSERT INTO invoices (invoice_id, test_record_id, total_amount, net_amount, status, generated_at) VALUES (602, 602, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 WEEK));

-- Patient 7 (Anisul) - CBC
INSERT INTO patient_tests (patient_id, test_id, record_id, doctor_id, payment_status, status) VALUES (7, 1, 603, 3, 'PAID', 'COMPLETED');
INSERT INTO invoices (invoice_id, test_record_id, total_amount, net_amount, status, generated_at) VALUES (603, 603, 600.00, 600.00, 'Paid', DATE_SUB(NOW(), INTERVAL 1 DAY));


-- =========================================================
-- PAYMENTS (Matches Invoices)
-- =========================================================
-- Using Temp Table to avoid 'Can't update table in trigger' error (Trigger updates Invoices, while Select reads Invoices)
CREATE TEMPORARY TABLE temp_payments_seed AS SELECT invoice_id, net_amount, generated_at FROM invoices WHERE invoice_id >= 200;
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) SELECT invoice_id, net_amount, 'Cash', generated_at FROM temp_payments_seed;
DROP TEMPORARY TABLE temp_payments_seed;

-- =========================================================
-- GUARANTEED ACTIVITY SEED (ENSURES EVERYONE HAS DATA)
-- =========================================================

-- DOC 1 (Cardiologist) - Extra
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(300, 1, 1, DATE_SUB(NOW(), INTERVAL 2 DAY), 'Completed', 'Routine Heart Check');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(300, 300, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 2 DAY));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES (300, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 2 DAY));

-- DOC 2 (Orthopedic) - Extra
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(301, 2, 2, DATE_SUB(NOW(), INTERVAL 3 DAY), 'Completed', 'Back Pain Review');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(301, 301, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 DAY));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES (301, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 3 DAY));

-- DOC 3 (Pediatrician) - Extra
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(302, 3, 3, DATE_SUB(NOW(), INTERVAL 4 DAY), 'Completed', 'Growth Check');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(302, 302, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 DAY));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES (302, 1200.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 DAY));

-- DOC 4 (Dermatologist) - Extra
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(303, 4, 4, DATE_SUB(NOW(), INTERVAL 5 DAY), 'Completed', 'Skin Allergy');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(303, 303, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 DAY));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES (303, 1800.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 DAY));

-- DOC 5 (Gynecology) - Extra
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(304, 5, 5, DATE_SUB(NOW(), INTERVAL 6 DAY), 'Completed', 'Consultation');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(304, 304, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 DAY));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES (304, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 DAY));

-- DOC 6 (General Med) - Extra
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(305, 6, 6, DATE_SUB(NOW(), INTERVAL 7 DAY), 'Completed', 'General Checkup');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(305, 305, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 7 DAY));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES (305, 800.00, 'Card', DATE_SUB(NOW(), INTERVAL 7 DAY));

-- DOC 7 (Neuro) - Extra
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(306, 7, 7, DATE_SUB(NOW(), INTERVAL 8 DAY), 'Completed', 'Headache Followup');
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(306, 306, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 8 DAY));
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES (306, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 8 DAY));

-- EXTRA PATIENT TESTS
INSERT INTO patient_tests (patient_id, test_id, record_id, doctor_id, payment_status, status) VALUES 
(5, 1, 700, 1, 'PAID', 'COMPLETED'), -- Salma CBC
(6, 2, 701, 2, 'PAID', 'COMPLETED'), -- James XRay
(7, 3, 702, 6, 'PAID', 'COMPLETED'); -- Anisul Lipid

INSERT INTO invoices (invoice_id, test_record_id, total_amount, net_amount, status, generated_at) VALUES 
(700, 700, 600.00, 600.00, 'Paid', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(701, 701, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(702, 702, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 DAY));

INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES
(700, 600.00, 'Cash', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(701, 800.00, 'Card', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(702, 1200.00, 'Online', DATE_SUB(NOW(), INTERVAL 3 DAY));

-- =========================================================
-- MASSIVE EXPANSION: ADDITIONAL COMPREHENSIVE SEED DATA
-- =========================================================

-- Additional Medicines for Prescriptions
INSERT INTO medicines (name, manufacturer, unit_price, stock_quantity) VALUES
('Ace 50mg', 'Square Pharma', 5.00, 4000),
('Amodis 500', 'Renata', 12.00, 3500),
('Atova 20', 'Incepta', 15.00, 2800),
('Ciprofloxacin 500', 'Beacon', 8.00, 4200),
('Montair 10', 'Square Pharma', 10.00, 3200),
('Fexo 120', 'Acme', 6.50, 3800),
('Dexona 0.5', 'UniMed', 1.50, 5500),
('Maxpro 40', 'Renata', 9.00, 3000),
('Pravidel 0.5', 'Square Pharma', 25.00, 1500),
('Insulin Actrapid', 'Novo Nordisk', 450.00, 800),
('Losectil 20', 'Square Pharma', 7.50, 3200),
('Zimax 500', 'Square Pharma', 20.00, 2400),
('Pantoprazole 40', 'Beximco', 6.00, 3600),
('Amdocal 5', 'Healthcare', 11.00, 2900),
('Tory 10', 'Incepta', 22.00, 2100),
('Flexi 90', 'Square Pharma', 35.00, 1800),
('Glemirel 2', 'Renata', 18.00, 2300),
('Rosumac 10', 'Acme', 24.00, 2000),
('Viagra 50', 'Pfizer', 65.00, 1200),
('Zolpidem 10', 'Square Pharma', 8.50, 2700);

-- Additional Lab Tests
INSERT INTO lab_tests (test_name, base_price, unit) VALUES
('HbA1c (Diabetes)', 900.00, '%'),
('Thyroid Function (TSH)', 700.00, 'mIU/L'),
('Liver Function Test', 1100.00, 'U/L'),
('Kidney Function Test', 1000.00, 'mg/dL'),
('Vitamin D', 1400.00, 'ng/mL'),
('Vitamin B12', 1200.00, 'pg/mL'),
('PSA (Prostate)', 1600.00, 'ng/mL'),
('Uric Acid', 400.00, 'mg/dL'),
('Blood Sugar (Fasting)', 250.00, 'mg/dL'),
('Blood Sugar (Random)', 200.00, 'mg/dL'),
('ECG', 600.00, 'reading'),
('Echocardiogram', 3500.00, 'reading'),
('Ultrasound (Abdomen)', 2000.00, 'image'),
('CT Scan (Brain)', 8000.00, 'image'),
('Endoscopy', 6500.00, 'procedure');

-- Additional Medical Tests
INSERT INTO medical_tests (test_name, description, cost, estimated_duration_minutes, assigned_room_number) VALUES
('Blood Sugar Fasting', 'Fasting glucose level measurement', 250.00, 1, 'Lab-001'),
('HbA1c Test', 'Glycated hemoglobin test for diabetes', 900.00, 2, 'Lab-001'),
('Thyroid Profile', 'Complete thyroid function tests', 1500.00, 2, 'Lab-002'),
('Liver Function Test', 'Complete LFT panel', 1100.00, 2, 'Lab-002'),
('Kidney Function Test', 'Creatinine, urea, and electrolytes', 1000.00, 2, 'Lab-002'),
('ECG Test', 'Electrocardiogram for heart rhythm', 600.00, 1, 'Rm-601'),
('Ultrasound Abdomen', 'Abdominal ultrasound imaging', 2000.00, 4, 'Lab-001'),
('CT Scan Brain', 'Computed tomography of brain', 8000.00, 6, 'Lab-001');

-- More Patient Users
INSERT INTO users (email, password_hash, role) VALUES 
('maria.lopez@careconnect.bd', 'patient123', 'Patient'), -- ID 17
('john.doe@careconnect.bd', 'patient123', 'Patient'), -- ID 18
('samira.khan@careconnect.bd', 'patient123', 'Patient'), -- ID 19
('robert.smith@careconnect.bd', 'patient123', 'Patient'), -- ID 20
('nadia.islam@careconnect.bd', 'patient123', 'Patient'), -- ID 21
('ahmed.hassan@careconnect.bd', 'patient123', 'Patient'), -- ID 22
('priya.sharma@careconnect.bd', 'patient123', 'Patient'), -- ID 23
('david.chen@careconnect.bd', 'patient123', 'Patient'), -- ID 24
('zahra.ali@careconnect.bd', 'patient123', 'Patient'), -- ID 25
('michael.brown@careconnect.bd', 'patient123', 'Patient'), -- ID 26
('ayesha.begum@careconnect.bd', 'patient123', 'Patient'), -- ID 27
('omar.farooq@careconnect.bd', 'patient123', 'Patient'), -- ID 28
('sophia.williams@careconnect.bd', 'patient123', 'Patient'), -- ID 29
('hassan.mahmud@careconnect.bd', 'patient123', 'Patient'), -- ID 30
('lisa.anderson@careconnect.bd', 'patient123', 'Patient'); -- ID 31

INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender, date_of_birth, address) VALUES
(17, 'Maria', 'Lopez', '01777777701', 'Female', '1988-03-15', 'Dhanmondi 27, Dhaka'),
(18, 'John', 'Doe', '01777777702', 'Male', '1975-08-22', 'Banani 11, Dhaka'),
(19, 'Samira', 'Khan', '01777777703', 'Female', '1995-11-30', 'Uttara Sector 10, Dhaka'),
(20, 'Robert', 'Smith', '01777777704', 'Male', '1968-05-10', 'Gulshan 1, Dhaka'),
(21, 'Nadia', 'Islam', '01777777705', 'Female', '1990-07-18', 'Mirpur 11, Dhaka'),
(22, 'Ahmed', 'Hassan', '01777777706', 'Male', '1982-12-25', 'Mohammadpur, Dhaka'),
(23, 'Priya', 'Sharma', '01777777707', 'Female', '1993-02-14', 'Lalmatia, Dhaka'),
(24, 'David', 'Chen', '01777777708', 'Male', '1970-09-05', 'Bashundhara R/A, Dhaka'),
(25, 'Zahra', 'Ali', '01777777709', 'Female', '1997-04-20', 'Kakrail, Dhaka'),
(26, 'Michael', 'Brown', '01777777710', 'Male', '1965-01-12', 'Baridhara DOHS, Dhaka'),
(27, 'Ayesha', 'Begum', '01777777711', 'Female', '1985-06-08', 'Malibagh, Dhaka'),
(28, 'Omar', 'Farooq', '01777777712', 'Male', '1978-10-30', 'Rampura, Dhaka'),
(29, 'Sophia', 'Williams', '01777777713', 'Female', '1992-08-16', 'Farmgate, Dhaka'),
(30, 'Hassan', 'Mahmud', '01777777714', 'Male', '1955-03-22', 'Eskaton, Dhaka'),
(31, 'Lisa', 'Anderson', '01777777715', 'Female', '1987-11-11', 'Segunbagicha, Dhaka');

INSERT INTO patients (user_id, blood_group, emergency_contact_first_name, emergency_contact_last_name, emergency_contact_phone) VALUES
(17, 'A+', 'Carlos', 'Lopez', '01888888801'),
(18, 'O+', 'Jane', 'Doe', '01888888802'),
(19, 'B+', 'Rahul', 'Khan', '01888888803'),
(20, 'AB+', 'Mary', 'Smith', '01888888804'),
(21, 'O-', 'Karim', 'Islam', '01888888805'),
(22, 'A-', 'Fatima', 'Hassan', '01888888806'),
(23, 'B-', 'Raj', 'Sharma', '01888888807'),
(24, 'AB-', 'Linda', 'Chen', '01888888808'),
(25, 'A+', 'Yusuf', 'Ali', '01888888809'),
(26, 'O+', 'Sarah', 'Brown', '01888888810'),
(27, 'B+', 'Rafiq', 'Begum', '01888888811'),
(28, 'A+', 'Mariam', 'Farooq', '01888888812'),
(29, 'AB+', 'Jack', 'Williams', '01888888813'),
(30, 'O-', 'Rehana', 'Mahmud', '01888888814'),
(31, 'A-', 'Tom', 'Anderson', '01888888815');

-- =========================================================
-- LARGE BATCH OF HISTORICAL APPOINTMENTS (6 MONTHS BACK)
-- =========================================================

-- Month 1 (6 months ago) - 25 appointments
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(400, 17, 1, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Heart Check'),
(401, 18, 2, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Knee Pain'),
(402, 19, 3, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Child Vaccine'),
(403, 20, 4, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Skin Rash'),
(404, 21, 5, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Gynec Consult'),
(405, 22, 6, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Fever'),
(406, 23, 7, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Migraine'),
(407, 24, 1, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'BP Check'),
(408, 25, 2, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Back Pain'),
(409, 26, 3, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Routine'),
(410, 27, 4, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Acne'),
(411, 28, 5, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Checkup'),
(412, 29, 6, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Cold'),
(413, 30, 7, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Headache'),
(414, 31, 1, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Chest Pain'),
(415, 1, 2, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Joint Pain'),
(416, 2, 3, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Checkup'),
(417, 3, 4, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Hair Loss'),
(418, 4, 5, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Consult'),
(419, 5, 6, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Weakness'),
(420, 6, 7, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Numbness'),
(421, 7, 1, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Heart'),
(422, 17, 2, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Fracture'),
(423, 18, 3, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Fever'),
(424, 19, 4, DATE_SUB(NOW(), INTERVAL 6 MONTH), 'Completed', 'Skin');

-- Invoices for Month 1
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(400, 400, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(401, 401, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(402, 402, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(403, 403, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(404, 404, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(405, 405, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(406, 406, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(407, 407, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(408, 408, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(409, 409, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(410, 410, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(411, 411, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(412, 412, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(413, 413, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(414, 414, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(415, 415, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(416, 416, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(417, 417, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(418, 418, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(419, 419, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(420, 420, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(421, 421, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(422, 422, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(423, 423, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(424, 424, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 MONTH));

-- Payments for Month 1
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES
(400, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(401, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(402, 1200.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(403, 1800.00, 'Online', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(404, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(405, 800.00, 'Card', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(406, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(407, 1500.00, 'Online', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(408, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(409, 1200.00, 'Card', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(410, 1800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(411, 1500.00, 'Online', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(412, 800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(413, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(414, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(415, 2000.00, 'Online', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(416, 1200.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(417, 1800.00, 'Card', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(418, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(419, 800.00, 'Online', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(420, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(421, 1500.00, 'Card', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(422, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(423, 1200.00, 'Online', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
(424, 1800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 6 MONTH));

-- Month 2 (5 months ago) - 30 appointments
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(500, 20, 1, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Follow-up'),
(501, 21, 2, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'X-Ray'),
(502, 22, 3, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Vaccine'),
(503, 23, 4, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Eczema'),
(504, 24, 5, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Pregnancy'),
(505, 25, 6, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Flu'),
(506, 26, 7, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Stress'),
(507, 27, 1, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'ECG'),
(508, 28, 2, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Arthritis'),
(509, 29, 3, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Checkup'),
(510, 30, 4, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Psoriasis'),
(511, 31, 5, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Menstrual'),
(512, 1, 6, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Diabetes'),
(513, 2, 7, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Seizure'),
(514, 3, 1, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Hypertension'),
(515, 4, 2, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Sprain'),
(516, 5, 3, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Growth'),
(517, 6, 4, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Allergy'),
(518, 7, 5, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'PCOS'),
(519, 17, 6, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Cough'),
(520, 18, 7, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Vertigo'),
(521, 19, 1, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Palpitation'),
(522, 20, 2, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Ligament'),
(523, 21, 3, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Asthma'),
(524, 22, 4, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Wart'),
(525, 23, 5, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'UTI'),
(526, 24, 6, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Gastritis'),
(527, 25, 7, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Anxiety'),
(528, 26, 1, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Cholesterol'),
(529, 27, 2, DATE_SUB(NOW(), INTERVAL 5 MONTH), 'Completed', 'Tendonitis');

-- Invoices for Month 2
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(500, 500, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(501, 501, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(502, 502, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(503, 503, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(504, 504, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(505, 505, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(506, 506, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(507, 507, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(508, 508, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(509, 509, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(510, 510, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(511, 511, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(512, 512, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(513, 513, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(514, 514, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(515, 515, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(516, 516, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(517, 517, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(518, 518, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(519, 519, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(520, 520, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(521, 521, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(522, 522, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(523, 523, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(524, 524, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(525, 525, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(526, 526, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(527, 527, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(528, 528, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(529, 529, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 MONTH));

-- Payments for Month 2
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES
(500, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(501, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(502, 1200.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(503, 1800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(504, 1500.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(505, 800.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(506, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(507, 1500.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(508, 2000.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(509, 1200.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(510, 1800.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(511, 1500.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(512, 800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(513, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(514, 1500.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(515, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(516, 1200.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(517, 1800.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(518, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(519, 800.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(520, 2000.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(521, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(522, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(523, 1200.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(524, 1800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(525, 1500.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(526, 800.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(527, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(528, 1500.00, 'Card', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
(529, 2000.00, 'Online', DATE_SUB(NOW(), INTERVAL 5 MONTH));

-- Month 3 (4 months ago) - 35 appointments
INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, reason) VALUES
(600, 28, 3, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Immunization'),
(601, 29, 4, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Fungal'),
(602, 30, 5, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Checkup'),
(603, 31, 6, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Bronchitis'),
(604, 1, 7, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Memory'),
(605, 2, 1, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Angina'),
(606, 3, 2, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Dislocation'),
(607, 4, 3, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Allergy Test'),
(608, 5, 4, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Vitiligo'),
(609, 6, 5, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Fibroids'),
(610, 7, 6, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Pneumonia'),
(611, 17, 7, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Epilepsy'),
(612, 18, 1, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Arrhythmia'),
(613, 19, 2, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Bursitis'),
(614, 20, 3, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Chickenpox'),
(615, 21, 4, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Melanoma'),
(616, 22, 5, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Endometriosis'),
(617, 23, 6, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Thyroid'),
(618, 24, 7, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Parkinsons'),
(619, 25, 1, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Aneurysm'),
(620, 26, 2, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Scoliosis'),
(621, 27, 3, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Measles'),
(622, 28, 4, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Cellulitis'),
(623, 29, 5, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Ovarian Cyst'),
(624, 30, 6, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Hepatitis'),
(625, 31, 7, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Dementia'),
(626, 1, 1, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Stress Test'),
(627, 2, 2, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'MRI Scan'),
(628, 3, 3, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Development'),
(629, 4, 4, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Mole Check'),
(630, 5, 5, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Infertility'),
(631, 6, 6, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Anemia'),
(632, 7, 7, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Neuropathy'),
(633, 17, 1, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Holter Test'),
(634, 18, 2, DATE_SUB(NOW(), INTERVAL 4 MONTH), 'Completed', 'Physiotherapy');

-- Invoices for Month 3
INSERT INTO invoices (invoice_id, appointment_id, total_amount, net_amount, status, generated_at) VALUES
(600, 600, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(601, 601, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(602, 602, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(603, 603, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(604, 604, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(605, 605, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(606, 606, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(607, 607, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(608, 608, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(609, 609, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(610, 610, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(611, 611, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(612, 612, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(613, 613, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(614, 614, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(615, 615, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(616, 616, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(617, 617, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(618, 618, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(619, 619, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(620, 620, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(621, 621, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(622, 622, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(623, 623, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(624, 624, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(625, 625, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(626, 626, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(627, 627, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(628, 628, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(629, 629, 1800.00, 1800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(630, 630, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(631, 631, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(632, 632, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(633, 633, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(634, 634, 2000.00, 2000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 MONTH));

-- Payments for Month 3
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES
(600, 1200.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(601, 1800.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(602, 1500.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(603, 800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(604, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(605, 1500.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(606, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(607, 1200.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(608, 1800.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(609, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(610, 800.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(611, 2000.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(612, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(613, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(614, 1200.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(615, 1800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(616, 1500.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(617, 800.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(618, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(619, 1500.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(620, 2000.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(621, 1200.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(622, 1800.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(623, 1500.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(624, 800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(625, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(626, 1500.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(627, 2000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(628, 1200.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(629, 1800.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(630, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(631, 800.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(632, 2000.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(633, 1500.00, 'Cash', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
(634, 2000.00, 'Card', DATE_SUB(NOW(), INTERVAL 4 MONTH));

-- =========================================================
-- MEDICAL RECORDS WITH PRESCRIPTIONS (Recent)
-- =========================================================

-- Records for recent appointments (last 30 days)
INSERT INTO medical_records (record_id, appointment_id, diagnosis, symptoms, vitals) VALUES
(1000, 300, 'Hypertension', 'Headache, Dizziness', '{"bp": "150/95", "hr": "78", "temp": "98.2"}'),
(1001, 301, 'Osteoarthritis', 'Joint Pain, Stiffness', '{"bp": "130/85", "hr": "72", "temp": "98.6"}'),
(1002, 302, 'Viral Fever', 'Fever, Body Ache', '{"bp": "120/80", "hr": "88", "temp": "101.3"}'),
(1003, 303, 'Dermatitis', 'Skin Rash, Itching', '{"bp": "125/82", "hr": "75", "temp": "98.4"}'),
(1004, 304, 'Normal Pregnancy', 'Routine Check', '{"bp": "118/75", "hr": "80", "temp": "98.6"}'),
(1005, 305, 'Upper Respiratory Infection', 'Cough, Cold', '{"bp": "122/78", "hr": "82", "temp": "99.5"}'),
(1006, 306, 'Migraine', 'Severe Headache', '{"bp": "135/88", "hr": "85", "temp": "98.4"}');

-- Prescriptions for these records
INSERT INTO prescriptions (prescription_id, record_id, notes) VALUES
(1000, 1000, 'Reduce salt intake. Monitor BP daily. Exercise 30 min/day.'),
(1001, 1001, 'Apply hot compress. Avoid heavy lifting. Follow up in 2 weeks.'),
(1002, 1002, 'Rest for 3 days. Drink plenty of fluids. Return if fever persists.'),
(1003, 1003, 'Avoid allergens. Use moisturizer. Apply ointment twice daily.'),
(1004, 1004, 'Take prenatal vitamins. Maintain healthy diet. Monthly checkup.'),
(1005, 1005, 'Steam inhalation. Warm liquids. Rest adequately.'),
(1006, 1006, 'Avoid stress and bright lights. Maintain sleep schedule.');

-- Prescription Items (Multiple medicines per prescription)
INSERT INTO prescription_items (prescription_id, medicine_id, dosage, frequency, duration_days) VALUES
(1000, 5, '50mg', '1-0-1', 30),
(1000, 13, '40mg', '0-1-0', 30),
(1001, 8, '500mg', '1-0-1', 15),
(1001, 16, '90mg', '0-0-1', 30),
(1002, 1, '500mg', '1-1-1', 5),
(1002, 6, '120mg', '1-0-1', 5),
(1003, 7, '0.5mg', '1-0-1', 7),
(1003, 10, '120mg', '0-1-0', 10),
(1004, 21, '400mcg', '0-0-1', 90),
(1005, 12, '500mg', '1-0-1', 5),
(1005, 9, '10mg', '1-0-1', 7),
(1006, 1, '500mg', '1-1-1', 3),
(1006, 14, '5mg', '0-0-1', 15);

-- =========================================================
-- LAB TEST RECORDS (Patient Tests)
-- =========================================================

INSERT INTO patient_tests (patient_id, test_id, record_id, doctor_id, payment_status, status, test_result) VALUES
(17, 1, 800, 1, 'PAID', 'COMPLETED', '{"hemoglobin": "13.5", "wbc": "7500", "platelets": "250000"}'),
(18, 2, 801, 2, 'PAID', 'COMPLETED', '{"findings": "No abnormality detected"}'),
(19, 3, 802, 5, 'PAID', 'COMPLETED', '{"hdl": "45", "ldl": "130", "triglycerides": "180"}'),
(20, 4, 803, 6, 'PAID', 'COMPLETED', '{"result": "Negative"}'),
(21, 5, 804, 1, 'PAID', 'COMPLETED', '{"hba1c": "6.8%"}'),
(22, 6, 805, 6, 'PAID', 'COMPLETED', '{"tsh": "3.2"}'),
(23, 7, 806, 6, 'PAID', 'COMPLETED', '{"alt": "32", "ast": "28", "bilirubin": "0.8"}'),
(24, 8, 807, 6, 'PAID', 'COMPLETED', '{"creatinine": "1.1", "urea": "32"}'),
(25, 9, 808, 6, 'PAID', 'COMPLETED', '{"level": "28 ng/mL"}'),
(26, 10, 809, 6, 'PAID', 'COMPLETED', '{"level": "450 pg/mL"}'),
(27, 11, 810, 2, 'PAID', 'COMPLETED', '{"psa": "1.8"}'),
(28, 12, 811, 6, 'PAID', 'COMPLETED', '{"uric_acid": "6.2"}'),
(29, 13, 812, 6, 'PAID', 'COMPLETED', '{"fasting": "102"}'),
(30, 14, 813, 6, 'PAID', 'COMPLETED', '{"random": "145"}'),
(31, 15, 814, 1, 'PAID', 'COMPLETED', '{"rhythm": "Normal Sinus", "rate": "75"}');

-- Invoices for Lab Tests
INSERT INTO invoices (invoice_id, test_record_id, total_amount, net_amount, status, generated_at) VALUES
(800, 800, 600.00, 600.00, 'Paid', DATE_SUB(NOW(), INTERVAL 15 DAY)),
(801, 801, 800.00, 800.00, 'Paid', DATE_SUB(NOW(), INTERVAL 14 DAY)),
(802, 802, 1500.00, 1500.00, 'Paid', DATE_SUB(NOW(), INTERVAL 13 DAY)),
(803, 803, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 12 DAY)),
(804, 804, 900.00, 900.00, 'Paid', DATE_SUB(NOW(), INTERVAL 11 DAY)),
(805, 805, 700.00, 700.00, 'Paid', DATE_SUB(NOW(), INTERVAL 10 DAY)),
(806, 806, 1100.00, 1100.00, 'Paid', DATE_SUB(NOW(), INTERVAL 9 DAY)),
(807, 807, 1000.00, 1000.00, 'Paid', DATE_SUB(NOW(), INTERVAL 8 DAY)),
(808, 808, 1400.00, 1400.00, 'Paid', DATE_SUB(NOW(), INTERVAL 7 DAY)),
(809, 809, 1200.00, 1200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 6 DAY)),
(810, 810, 1600.00, 1600.00, 'Paid', DATE_SUB(NOW(), INTERVAL 5 DAY)),
(811, 811, 400.00, 400.00, 'Paid', DATE_SUB(NOW(), INTERVAL 4 DAY)),
(812, 812, 250.00, 250.00, 'Paid', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(813, 813, 200.00, 200.00, 'Paid', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(814, 814, 600.00, 600.00, 'Paid', DATE_SUB(NOW(), INTERVAL 1 DAY));

-- Payments for Lab Tests
INSERT INTO payments (invoice_id, amount, payment_method, payment_date) VALUES
(800, 600.00, 'Card', DATE_SUB(NOW(), INTERVAL 15 DAY)),
(801, 800.00, 'Cash', DATE_SUB(NOW(), INTERVAL 14 DAY)),
(802, 1500.00, 'Online', DATE_SUB(NOW(), INTERVAL 13 DAY)),
(803, 1200.00, 'Card', DATE_SUB(NOW(), INTERVAL 12 DAY)),
(804, 900.00, 'Cash', DATE_SUB(NOW(), INTERVAL 11 DAY)),
(805, 700.00, 'Online', DATE_SUB(NOW(), INTERVAL 10 DAY)),
(806, 1100.00, 'Card', DATE_SUB(NOW(), INTERVAL 9 DAY)),
(807, 1000.00, 'Cash', DATE_SUB(NOW(), INTERVAL 8 DAY)),
(808, 1400.00, 'Online', DATE_SUB(NOW(), INTERVAL 7 DAY)),
(809, 1200.00, 'Card', DATE_SUB(NOW(), INTERVAL 6 DAY)),
(810, 1600.00, 'Cash', DATE_SUB(NOW(), INTERVAL 5 DAY)),
(811, 400.00, 'Online', DATE_SUB(NOW(), INTERVAL 4 DAY)),
(812, 250.00, 'Card', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(813, 200.00, 'Cash', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(814, 600.00, 'Online', DATE_SUB(NOW(), INTERVAL 1 DAY));

-- =========================================================
-- FINAL SUMMARY STATISTICS
-- Total Users: 31 (Patients: 22, Doctors: 7, Admin: 1, Staff: 1)
-- Total Appointments: 634+
-- Total Revenue Generated: ~100,000+ BDT
-- Time Span: Last 6 months of comprehensive data
-- =========================================================

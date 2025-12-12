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
('CBC (Complete Blood Count)', 'Evaluates overall health and detects a wide range of disorders.', 500.00, 15, 'Lab-001'),
('Chest X-Ray', 'Produces images of the heart, lungs, airways, blood vessels and the bones of the spine and chest.', 800.00, 20, 'XRay-01'),
('MRI Scan', 'Magnetic Resonance Imaging using strong magnetic fields.', 5000.00, 60, 'MRI-01'),
('Lipid Profile', 'Measures cholesterol and other fats in blood.', 1200.00, 15, 'Lab-001'),
('Urinalysis', 'Test of urine.', 300.00, 10, 'Lab-002');

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

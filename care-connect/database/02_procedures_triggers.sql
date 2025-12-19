-- Procedures, Functions, and Triggers for CareConnect

USE careconnect;

DELIMITER //

-- =============================================
-- FUNCTIONS
-- =============================================

-- 1. CalculateAge Function
CREATE FUNCTION CalculateAge(dob DATE) 
RETURNS INT
DETERMINISTIC
BEGIN
    RETURN TIMESTAMPDIFF(YEAR, dob, CURDATE());
END //

-- 2. Check Doctor Availability & Capacity
CREATE FUNCTION IsDoctorAvailable(doc_id INT, appt_datetime DATETIME)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE conflict_count INT;
    DECLARE day_name VARCHAR(15);
    DECLARE schedule_exists INT;
    DECLARE daily_appt_count INT;
    DECLARE MAX_APPOINTMENTS_PER_DAY INT DEFAULT 5; -- Business Rule: Max 5 bookings per doctor per day

    -- 1. Check if the Doctor is even working on this day/time
    SET day_name = DAYNAME(appt_datetime); -- e.g., 'Monday'
    
    SELECT COUNT(*) INTO schedule_exists
    FROM schedules
    WHERE doctor_id = doc_id
      AND day_of_week = day_name
      AND TIME(appt_datetime) BETWEEN start_time AND end_time;

    IF schedule_exists = 0 THEN
        RETURN FALSE; -- Doctor is not scheduled to work at this time
    END IF;

    -- 2. Check Capacity Limit (Max 10 per day)
    SELECT COUNT(*) INTO daily_appt_count
    FROM appointments
    WHERE doctor_id = doc_id 
      AND DATE(appointment_date) = DATE(appt_datetime)
      AND status NOT IN ('Cancelled', 'NoShow');
      
    IF daily_appt_count >= MAX_APPOINTMENTS_PER_DAY THEN
        RETURN FALSE; -- Daily capacity reached
    END IF;

    -- 3. Check for specific Time Slot Conflicts (Double booking)
    SELECT COUNT(*) INTO conflict_count
    FROM appointments
    WHERE doctor_id = doc_id 
      AND status NOT IN ('Cancelled', 'NoShow')
      AND appointment_date = appt_datetime; -- Exact match check
      
    IF conflict_count > 0 THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END IF;
END //

-- 3. Calculate Appointment Total Cost (Consultation + Tests + Meds)
CREATE FUNCTION GetConsultationFee(doc_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE fee DECIMAL(10,2);
    SELECT consultation_fee INTO fee FROM doctors WHERE doctor_id = doc_id;
    RETURN IFNULL(fee, 0);
END //

-- =============================================
-- STORED PROCEDURES
-- =============================================

-- 1. Book Appointment (Transactional)
CREATE PROCEDURE BookAppointment(
    IN p_patient_id INT,
    IN p_doctor_id INT,
    IN p_date DATETIME,
    IN p_reason TEXT,
    OUT p_status VARCHAR(255),
    OUT p_invoice_id INT
)
BEGIN
    DECLARE p_new_appointment_id INT;
    DECLARE v_consultation_fee DECIMAL(10, 2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @sqlstate = RETURNED_SQLSTATE, @errno = MYSQL_ERRNO, @text = MESSAGE_TEXT;
        ROLLBACK;
        SET p_status = CONCAT('Error: ', @text);
    END;

    START TRANSACTION;

    -- Validations
    IF NOT IsDoctorAvailable(p_doctor_id, p_date) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor unavailable: Schedule mismatch, Capacity full, or Slot taken.';
    END IF;

    -- Validate Reason for Visit against Doctor's Department
    IF NOT EXISTS (
        SELECT 1 
        FROM appointment_reasons ar
        JOIN doctors d ON ar.dept_id = d.dept_id
        WHERE d.doctor_id = p_doctor_id
          AND ar.reason_text = p_reason
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid reason for this specialist.';
    END IF;

    -- Insert appointment with 'Pending_Payment' status
    INSERT INTO appointments (patient_id, doctor_id, appointment_date, reason, status)
    VALUES (p_patient_id, p_doctor_id, p_date, p_reason, 'Pending_Payment');
    
    SET p_new_appointment_id = LAST_INSERT_ID();
    
    -- Fetch Doctor's Consultation Fee
    SELECT consultation_fee INTO v_consultation_fee 
    FROM doctors WHERE doctor_id = p_doctor_id;
    
    -- Generate Invoice Automatically (Unpaid)
    INSERT INTO invoices (appointment_id, total_amount, net_amount, status)
    VALUES (p_new_appointment_id, v_consultation_fee, v_consultation_fee, 'Unpaid');
    
    SET p_invoice_id = LAST_INSERT_ID();

    COMMIT;
    SET p_status = 'Pending Payment';
END //

-- 2. Get Detailed Doctor Availability (For UI Feedback)
CREATE PROCEDURE GetDoctorSlots(
    IN p_doctor_id INT,
    IN p_date DATETIME,
    OUT p_remaining_slots INT,
    OUT p_is_available BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_max_slots INT DEFAULT 5;
    DECLARE v_current_bookings INT;
    DECLARE v_schedule_count INT;
    DECLARE v_day_name VARCHAR(15);
    
    SET v_day_name = DAYNAME(p_date);
    
    -- 1. Check Schedule (Day & Time)
    SELECT COUNT(*) INTO v_schedule_count
    FROM schedules
    WHERE doctor_id = p_doctor_id
      AND day_of_week = v_day_name
      AND TIME(p_date) BETWEEN start_time AND end_time;
      
    IF v_schedule_count = 0 THEN
        SET p_is_available = FALSE;
        SET p_message = CONCAT('Doctor not scheduled on ', v_day_name, ' at this time.');
        SET p_remaining_slots = 0;
    ELSE
        -- 2. Check Capacity
        SELECT COUNT(*) INTO v_current_bookings
        FROM appointments
        WHERE doctor_id = p_doctor_id
          AND DATE(appointment_date) = DATE(p_date)
          AND status NOT IN ('Cancelled', 'NoShow');
          
        SET p_remaining_slots = v_max_slots - v_current_bookings;
        
        IF p_remaining_slots <= 0 THEN
            SET p_is_available = FALSE;
            SET p_remaining_slots = 0;
            SET p_message = 'Doctor is fully booked for this date.';
        ELSE
            -- 3. Check Exact Slot Conflict
            IF EXISTS (SELECT 1 FROM appointments WHERE doctor_id = p_doctor_id AND appointment_date = p_date AND status != 'Cancelled') THEN
                SET p_is_available = FALSE;
                SET p_message = 'This specific time slot is already taken.';
            ELSE
                SET p_is_available = TRUE;
                SET p_message = 'Available';
            END IF;
        END IF;
    END IF;
END //



-- 3. Dynamic Slot Generation (The "Database Heavy" Logic)
CREATE PROCEDURE GetAvailableTimeSlots(
    IN p_doctor_id INT,
    IN p_date DATE
)
BEGIN
    DECLARE v_start_time TIME;
    DECLARE v_end_time TIME;
    DECLARE v_curr_time TIME;
    DECLARE v_slot_duration INT DEFAULT 30; -- 30 minute intervals
    DECLARE v_day_name VARCHAR(15);
    
    SET v_day_name = DAYNAME(p_date);
    
    -- Create temp table to store valid slots
    DROP TEMPORARY TABLE IF EXISTS TempSlots;
    CREATE TEMPORARY TABLE TempSlots (
        slot_time TIME, 
        formatted_time VARCHAR(20),
        is_booked BOOLEAN DEFAULT FALSE
    );
    
    -- 1. Get Doctor's Schedule limits for that specific Day
    SELECT start_time, end_time INTO v_start_time, v_end_time
    FROM schedules
    WHERE doctor_id = p_doctor_id AND day_of_week = v_day_name;
    
    -- 2. Loop to generate slots
    IF v_start_time IS NOT NULL THEN
        SET v_curr_time = v_start_time;
        
        WHILE v_curr_time < v_end_time DO
             -- Check if this specific slot is already booked in appointments table
             IF EXISTS (
                SELECT 1 FROM appointments 
                WHERE doctor_id = p_doctor_id 
                AND DATE(appointment_date) = p_date 
                AND TIME(appointment_date) = v_curr_time
                AND status NOT IN ('Cancelled', 'NoShow')
             ) THEN
                INSERT INTO TempSlots VALUES (v_curr_time, DATE_FORMAT(v_curr_time, '%h:%i %p'), TRUE);
             ELSE
                INSERT INTO TempSlots VALUES (v_curr_time, DATE_FORMAT(v_curr_time, '%h:%i %p'), FALSE);
             END IF;
             
             -- Increment time
             SET v_curr_time = ADDTIME(v_curr_time, SEC_TO_TIME(v_slot_duration * 60));
        END WHILE;
    END IF;
    
    -- Return only available slots
    SELECT * FROM TempSlots WHERE is_booked = FALSE;
END //

-- 5. Admin Login Verification (Database-Driven Security)
CREATE PROCEDURE VerifyAdminCredentials(
    IN p_email VARCHAR(100),
    IN p_password VARCHAR(255),
    OUT p_is_valid INT,
    OUT p_user_id INT,
    OUT p_role VARCHAR(20)
)
BEGIN
    DECLARE v_stored_hash VARCHAR(255);
    DECLARE v_user_id INT;
    DECLARE v_role VARCHAR(20);
    
    -- Check if user exists
    SELECT user_id, password_hash, role 
    INTO v_user_id, v_stored_hash, v_role
    FROM users 
    WHERE email = p_email 
    LIMIT 1;
    
    IF v_user_id IS NOT NULL THEN
        -- In a real scenario, use SHA2() or similar. Here we compare plain/placeholder hash.
        IF v_stored_hash = p_password AND v_role IN ('Admin', 'Doctor', 'Staff') THEN -- Allow Admin, Doctors, and Staff
            SET p_is_valid = 1;
            SET p_user_id = v_user_id;
            SET p_role = v_role;
        ELSE
            SET p_is_valid = 0;
        END IF;
    ELSE
        SET p_is_valid = 0;
    END IF;
END //

-- 6. Confirm Payment (Finalizes Booking)
CREATE PROCEDURE ConfirmPayment(
    IN p_invoice_id INT,
    IN p_amount_paid DECIMAL(10,2),
    IN p_payment_method VARCHAR(20),
    OUT p_status VARCHAR(50)
)
BEGIN
    DECLARE v_net_amount DECIMAL(10,2);
    DECLARE v_appt_id INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = 'Error';
    END;

    START TRANSACTION;
    
    -- Get Invoice Details
    SELECT net_amount, appointment_id INTO v_net_amount, v_appt_id
    FROM invoices WHERE invoice_id = p_invoice_id;
    
    IF v_net_amount IS NULL THEN
        SET p_status = 'Invoice Not Found';
    ELSEIF p_amount_paid < v_net_amount THEN
        SET p_status = 'Insufficient Amount';
    ELSE
        -- 1. Record Payment
        INSERT INTO payments (invoice_id, amount, payment_method)
        VALUES (p_invoice_id, p_amount_paid, p_payment_method);
        
        -- 2. Mark Invoice as Paid
        UPDATE invoices SET status = 'Paid' WHERE invoice_id = p_invoice_id;
        
        -- 3. Confirm Appointment (Triggered by payment)
        UPDATE appointments SET status = 'Scheduled' WHERE appointment_id = v_appt_id;
        
        SET p_status = 'Success';
    END IF;
    
    COMMIT;
END //

-- 7. Get Financial Analytics (Heavy Aggregation)
CREATE PROCEDURE GetFinancialSummary()
BEGIN
    SELECT 
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid') 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock') as total_all_time,
        
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 YEAR)) 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 YEAR)) as total_last_year,
        
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)) 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 MONTH)) as total_last_month,
        
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE status = 'Paid' AND generated_at >= DATE_SUB(NOW(), INTERVAL 1 WEEK)) 
        - (SELECT COALESCE(SUM(amount), 0) FROM hospital_expenses WHERE category = 'Pharmacy_Restock' AND expense_date >= DATE_SUB(NOW(), INTERVAL 1 WEEK)) as total_last_week;
END //


-- 4. Generate Full Invoice (Complex Logic)
-- Aggregates Consultation Fee + Prescribed Medicines + Lab Tests
CREATE PROCEDURE GenerateInvoice(
    IN p_appointment_id INT
)
BEGIN
    DECLARE v_doc_fee DECIMAL(10,2);
    DECLARE v_med_total DECIMAL(10,2);
    DECLARE v_lab_total DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_doctor_id INT;
    DECLARE v_record_id INT;

    -- Get Doctor Fee
    SELECT doctor_id INTO v_doctor_id FROM appointments WHERE appointment_id = p_appointment_id;
    SET v_doc_fee = GetConsultationFee(v_doctor_id);

    -- Get Medical Record ID
    SELECT record_id INTO v_record_id FROM medical_records WHERE appointment_id = p_appointment_id;

    -- Sum Medicines Cost
    -- Join Prescriptions -> PrescriptionItems -> Medicines
    SELECT IFNULL(SUM(m.unit_price * pi.duration_days * 1), 0) -- Simplified calc based on dosage assumption or just unit price
    INTO v_med_total
    FROM prescriptions p
    JOIN prescription_items pi ON p.prescription_id = pi.prescription_id
    JOIN medicines m ON pi.medicine_id = m.medicine_id
    WHERE p.record_id = v_record_id;

    -- Sum Lab Tests Cost
    SELECT IFNULL(SUM(lt.base_price), 0)
    INTO v_lab_total
    FROM lab_results lr
    JOIN lab_tests lt ON lr.test_id = lt.test_id
    WHERE lr.record_id = v_record_id;

    SET v_total = v_doc_fee + v_med_total + v_lab_total;

    INSERT INTO invoices (appointment_id, total_amount, net_amount, status)
    VALUES (p_appointment_id, v_total, v_total, 'Unpaid');
    
END //

-- 3. Admit Patient (Optional or Update Status Procedure)
CREATE PROCEDURE UpdateAppointmentStatus(
    IN p_appt_id INT,
    IN p_status VARCHAR(20)
)
BEGIN
    UPDATE appointments SET status = p_status WHERE appointment_id = p_appt_id;
END //

-- =============================================
-- TRIGGERS
-- =============================================

-- 1. Check Medicine Stock BEFORE Prescription Insert (Validation)
CREATE TRIGGER trg_check_med_stock
BEFORE INSERT ON prescription_items
FOR EACH ROW
BEGIN
    DECLARE current_stock INT;
    SELECT stock_quantity INTO current_stock FROM medicines WHERE medicine_id = NEW.medicine_id;
    
    IF current_stock < 1 THEN -- Check if at least 1 is available (simplified logic)
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Medicine Out of Stock';
    END IF;
END //

-- 2. Validate Appointment Date BEFORE INSERT
CREATE TRIGGER trg_validate_appointment_date
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
    IF NEW.appointment_date < NOW() AND NEW.status != 'Completed' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot schedule appointment in the past.';
    END IF;
END //

-- 2. Audit Log Trigger AFTER Update on Appointments
CREATE TRIGGER trg_audit_appointment_update
AFTER UPDATE ON appointments
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (table_name, action_type, record_id, old_value, new_value, performed_at)
    VALUES (
        'appointments', 
        'UPDATE', 
        NEW.appointment_id, 
        JSON_OBJECT('status', OLD.status, 'date', OLD.appointment_date),
        JSON_OBJECT('status', NEW.status, 'date', NEW.appointment_date),
        NOW()
    );
END //

-- 3. Update Invoice Status AFTER full payment
CREATE TRIGGER trg_update_invoice_paid
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_paid DECIMAL(10,2);
    
    SELECT total_amount INTO v_total FROM invoices WHERE invoice_id = NEW.invoice_id;
    SELECT SUM(amount) INTO v_paid FROM payments WHERE invoice_id = NEW.invoice_id;
    
    IF v_paid >= v_total THEN
        UPDATE invoices SET status = 'Paid' WHERE invoice_id = NEW.invoice_id;
    END IF;
END //

-- 3b. Auto-Schedule Appointment when Invoice is Paid (Catch-all)
CREATE TRIGGER trg_invoice_paid_schedule_appointment
AFTER UPDATE ON invoices
FOR EACH ROW
BEGIN
    IF NEW.status = 'Paid' AND OLD.status != 'Paid' AND NEW.appointment_id IS NOT NULL THEN
        UPDATE appointments 
        SET status = 'Scheduled' 
        WHERE appointment_id = NEW.appointment_id AND status = 'Pending_Payment';
    END IF;
END //



-- 4. Validate Email Format (Users Table)
CREATE TRIGGER trg_validate_user_email
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    IF NOT (NEW.email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid email format. Please provide a valid email address.';
    END IF;
END //

-- 5. Validate Phone Number (Bangladeshi Format)
-- Accepts: +8801xxxxxxxxx (14 digits) or 01xxxxxxxxx (11 digits)
CREATE TRIGGER trg_validate_bd_phone
BEFORE INSERT ON profiles
FOR EACH ROW
BEGIN
    -- Check if it matches +8801... (14 chars) or 01... (11 chars)
    IF NOT (NEW.phone_number REGEXP '^(?:\\+88)?01[3-9][0-9]{8}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid phone number. Must be a valid Bangladeshi mobile number (e.g., 017xxxxxxxx or +88017xxxxxxxx).';
    END IF;
END //

-- 6. Auto-Update Medical History Summary on New Appointment Booking
CREATE TRIGGER trg_update_history_on_book
AFTER INSERT ON appointments
FOR EACH ROW
BEGIN
    UPDATE patients 
    SET medical_history_summary = CONCAT(
        COALESCE(medical_history_summary, ''), 
        '\n[', DATE_FORMAT(NEW.appointment_date, '%Y-%m-%d'), ']: ', NEW.reason
    )
    WHERE patient_id = NEW.patient_id;
END //

-- 7. Validate Doctor License (Must be in whitelist and not taken)
CREATE TRIGGER trg_validate_doctor_license
BEFORE INSERT ON doctors
FOR EACH ROW
BEGIN
    DECLARE v_is_registered BOOLEAN DEFAULT NULL;

    -- Check if license exists and get its status
    SELECT is_registered INTO v_is_registered 
    FROM valid_medical_licenses 
    WHERE license_number = NEW.license_number;

    IF v_is_registered IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid License ID. Not found in official registry.';
    -- Allow reuse if the doctor is the SAME user (updating profile) - simplified check primarily for insert
    ELSEIF v_is_registered = TRUE THEN
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'License ID already in use by another registered doctor.';
    END IF;
END //

-- 8. Mark License as Registered After Insert
CREATE TRIGGER trg_mark_license_used
AFTER INSERT ON doctors
FOR EACH ROW
BEGIN
    UPDATE valid_medical_licenses SET is_registered = TRUE WHERE license_number = NEW.license_number;
END //

-- 9. Validate Doctor Specialization and Fee (Must exist in Lookup Tables)
CREATE TRIGGER trg_validate_doctor_details
BEFORE INSERT ON doctors
FOR EACH ROW
BEGIN
    -- Check Specialization
    IF NOT EXISTS (SELECT 1 FROM valid_specializations WHERE specialization_name = NEW.specialization) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid Specialization. Please choose from the allowed list.';
    END IF;

    -- Check Fee
    IF NOT EXISTS (SELECT 1 FROM valid_consultation_fees WHERE amount = NEW.consultation_fee) THEN
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid Consultation Fee. Must be a valid tier (e.g., 500, 1000, 1500, 2000).';
    END IF;
END //


DELIMITER ;

-- 15. Enforce Test Payment before Scheduling
DELIMITER //
CREATE TRIGGER trg_enforce_test_payment_before_scheduling
BEFORE UPDATE ON patient_tests
FOR EACH ROW
BEGIN
    -- If trying to set a scheduled date
    IF NEW.scheduled_date IS NOT NULL AND (OLD.scheduled_date IS NULL OR OLD.scheduled_date != NEW.scheduled_date) THEN
        -- Check if payment is paid
        IF NEW.payment_status != 'PAID' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot schedule test until payment is made.';
        END IF;

        -- Auto update status to SCHEDULED if it was PENDING_PAYMENT
        IF NEW.status = 'PENDING_PAYMENT' THEN
            SET NEW.status = 'SCHEDULED';
        END IF;

        -- Calculate End Time
        SELECT estimated_duration_minutes INTO @duration FROM medical_tests WHERE test_id = NEW.test_id;
        SET NEW.scheduled_end_time = DATE_ADD(NEW.scheduled_date, INTERVAL @duration MINUTE);
    END IF;
END //
DELIMITER ;

-- 16. Auto-Assign Room on Test Order Creation
DELIMITER //
CREATE TRIGGER trg_set_test_defaults
BEFORE INSERT ON patient_tests
FOR EACH ROW
BEGIN
    DECLARE default_room VARCHAR(20);
    SELECT assigned_room_number INTO default_room FROM medical_tests WHERE test_id = NEW.test_id;
    
    IF NEW.room_number IS NULL THEN
        SET NEW.room_number = default_room;
    END IF;
END //
DELIMITER ;

-- 17. Auto-Generate Invoice for Paid Tests (Moved to post-seed)
-- Trigger `trg_create_test_invoice` is now applied after seeding to allow manual invoice creation for history.



-- 19. Auto-Update Test History Summary on Test Completion
DELIMITER //
CREATE TRIGGER trg_update_patient_test_history
AFTER UPDATE ON patient_tests
FOR EACH ROW
BEGIN
    DECLARE v_test_name VARCHAR(100);
    
    -- Trigger if:
    -- 1. Status is COMPLETED
    -- 2. AND (Status just changed TO Completed OR Result Summary Changed)
    -- Using NOT (<=>) for NULL-safe inequality check
    IF (NEW.status = 'COMPLETED') AND 
       (
          (OLD.status != 'COMPLETED') OR 
          (NOT (NEW.result_summary <=> OLD.result_summary))
       ) THEN
       
        -- Get Test Name
        SELECT test_name INTO v_test_name FROM medical_tests WHERE test_id = NEW.test_id;
        
        UPDATE patients 
        SET test_history_summary = CONCAT(
            COALESCE(test_history_summary, ''), 
            '\n[', DATE_FORMAT(NOW(), '%Y-%m-%d'), ']: ', v_test_name, ' - ', COALESCE(NEW.result_summary, 'Completed')
        )
        WHERE patient_id = NEW.patient_id;
    END IF;
END //
DELIMITER ;

-- 18. Update Invoice When Test Payment Status Changes
DELIMITER //
CREATE TRIGGER trg_update_test_invoice
AFTER UPDATE ON patient_tests
FOR EACH ROW
BEGIN
    DECLARE test_cost DECIMAL(10, 2);
    DECLARE existing_invoice INT;
    
    -- Check if payment status changed from PENDING to PAID
    IF OLD.payment_status = 'PENDING' AND NEW.payment_status = 'PAID' THEN
        -- Check if invoice already exists
        SELECT invoice_id INTO existing_invoice FROM invoices WHERE test_record_id = NEW.record_id LIMIT 1;
        
        IF existing_invoice IS NULL THEN
            -- Get test cost
            SELECT cost INTO test_cost FROM medical_tests WHERE test_id = NEW.test_id;
            
            -- Create invoice
            INSERT INTO invoices (test_record_id, total_amount, discount_amount, net_amount, status, generated_at)
            VALUES (NEW.record_id, test_cost, 0.00, test_cost, 'Paid', NOW());
        ELSE
            -- Update existing invoice to Paid
            UPDATE invoices SET status = 'Paid' WHERE invoice_id = existing_invoice;
        END IF;
    END IF;
END //
DELIMITER ;

-- 20. Get Available Rooms by Type
DELIMITER //
CREATE PROCEDURE GetRoomAvailability(
    IN p_room_type VARCHAR(20)
)
BEGIN
    SELECT r.room_number, r.charge_per_day, r.type
    FROM rooms r
    WHERE r.type = p_room_type
      AND r.is_available = TRUE -- Administrative availability
      AND NOT EXISTS (
          SELECT 1 FROM admissions a 
          WHERE a.room_number = r.room_number 
            AND a.status = 'Admitted'
      );
END //
DELIMITER ;

-- 21. Admit Patient (Book Room)
DELIMITER //
CREATE PROCEDURE AdmitPatient(
    IN p_patient_id INT,
    IN p_room_type VARCHAR(20),
    OUT p_room_number VARCHAR(20),
    OUT p_status VARCHAR(50)
)
BEGIN
    DECLARE v_room_num VARCHAR(20);
    
    -- Find first available room
    SELECT r.room_number INTO v_room_num
    FROM rooms r
    WHERE r.type = p_room_type
      AND r.is_available = TRUE
      AND NOT EXISTS (
          SELECT 1 FROM admissions a 
          WHERE a.room_number = r.room_number 
            AND a.status = 'Admitted'
      )
    LIMIT 1;
    
    IF v_room_num IS NOT NULL THEN
        INSERT INTO admissions (patient_id, room_number, status, payment_status)
        VALUES (p_patient_id, v_room_num, 'Admitted', 'Pending');
        
        -- IMPORTANT: Mark room as unavailable
        UPDATE rooms SET is_available = FALSE WHERE room_number = v_room_num;
        
        SET p_room_number = v_room_num;
        SET p_status = 'Success';
    ELSE
        SET p_room_number = NULL;
        SET p_status = 'No Rooms Available';
    END IF;
END //
DELIMITER ;

-- 22. Discharge Patient
DELIMITER //
CREATE PROCEDURE DischargePatient(
    IN p_admission_id INT
)
BEGIN
    DECLARE v_charge DECIMAL(10, 2);
    DECLARE v_days INT;
    DECLARE v_start_time TIMESTAMP;
    DECLARE v_room VARCHAR(20);
    
    SELECT admission_date, room_number INTO v_start_time, v_room 
    FROM admissions WHERE admission_id = p_admission_id;
    
    -- Calculate Duration (at least 1 day)
    SET v_days = DATEDIFF(NOW(), v_start_time);
    IF v_days < 1 THEN SET v_days = 1; END IF;
    
    
    -- Get Room Charge
    SELECT charge_per_day INTO v_charge FROM rooms WHERE room_number = v_room;
    
    UPDATE admissions 
    SET status = 'Discharged', 
        discharge_date = NOW(),
        total_cost = (v_charge * v_days)
    WHERE admission_id = p_admission_id;
    
    -- IMPORTANT: Mark room as available again
    UPDATE rooms SET is_available = TRUE WHERE room_number = v_room;
END //

-- 23. Finalize Pharmacy Order on Invoice Payment
DELIMITER //
CREATE TRIGGER trg_finalize_pharmacy_order
AFTER UPDATE ON invoices
FOR EACH ROW
BEGIN
    IF NEW.status = 'Paid' AND OLD.status != 'Paid' AND NEW.pharmacy_order_id IS NOT NULL THEN
        UPDATE pharmacy_orders 
        SET status = 'Completed' 
        WHERE order_id = NEW.pharmacy_order_id;
    END IF;
END //
DELIMITER ;

-- 24. Deduct Medicine Stock on Order Completion
DELIMITER //
CREATE TRIGGER trg_deduct_medicine_stock
AFTER UPDATE ON pharmacy_orders
FOR EACH ROW
BEGIN
    IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
        -- Reduce stock for each item in the order
        UPDATE medicines m
        JOIN pharmacy_order_items poi ON m.medicine_id = poi.medicine_id
        SET m.stock_quantity = m.stock_quantity - poi.quantity
        WHERE poi.order_id = NEW.order_id;
    END IF;
END //
DELIMITER ;

-- =============================================
-- ADDITIONAL PROCEDURES & TRIGGERS
-- =============================================

-- 25. Get Equipment Maintenance Schedule
DELIMITER //
CREATE PROCEDURE GetEquipmentMaintenanceSchedule(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        ei.equipment_id,
        ei.equipment_name,
        ei.equipment_type,
        ei.assigned_room,
        ei.current_status,
        eml.next_maintenance_date,
        eml.maintenance_type,
        d.name AS department_name
    FROM equipment_inventory ei
    LEFT JOIN equipment_maintenance_log eml ON ei.equipment_id = eml.equipment_id
    LEFT JOIN departments d ON ei.assigned_dept_id = d.dept_id
    WHERE eml.next_maintenance_date BETWEEN p_start_date AND p_end_date
    ORDER BY eml.next_maintenance_date ASC;
END //
DELIMITER ;

-- 26. Log Equipment Maintenance
DELIMITER //
CREATE PROCEDURE LogEquipmentMaintenance(
    IN p_equipment_id INT,
    IN p_maintenance_type ENUM('Routine', 'Repair', 'Calibration', 'Emergency'),
    IN p_performed_by VARCHAR(100),
    IN p_cost DECIMAL(10,2),
    IN p_description TEXT,
    IN p_next_maintenance_days INT
)
BEGIN
    DECLARE v_next_date DATE;
    
    SET v_next_date = DATE_ADD(CURDATE(), INTERVAL p_next_maintenance_days DAY);
    
    INSERT INTO equipment_maintenance_log (
        equipment_id, maintenance_type, maintenance_date, 
        performed_by, cost, description, next_maintenance_date
    ) VALUES (
        p_equipment_id, p_maintenance_type, NOW(),
        p_performed_by, p_cost, p_description, v_next_date
    );
    
    UPDATE equipment_inventory 
    SET current_status = 'Operational'
    WHERE equipment_id = p_equipment_id;
END //
DELIMITER ;

-- 27. Record Staff Attendance
DELIMITER //
CREATE PROCEDURE RecordStaffCheckIn(
    IN p_user_id INT
)
BEGIN
    DECLARE v_today DATE;
    DECLARE v_existing INT;
    
    SET v_today = CURDATE();
    
    SELECT COUNT(*) INTO v_existing 
    FROM staff_attendance 
    WHERE user_id = p_user_id AND attendance_date = v_today;
    
    IF v_existing = 0 THEN
        INSERT INTO staff_attendance (user_id, check_in_time, attendance_date, status)
        VALUES (p_user_id, NOW(), v_today, 'Present');
    END IF;
END //
DELIMITER ;

-- 28. Record Staff Checkout
DELIMITER //
CREATE PROCEDURE RecordStaffCheckOut(
    IN p_user_id INT
)
BEGIN
    UPDATE staff_attendance 
    SET check_out_time = NOW()
    WHERE user_id = p_user_id 
      AND attendance_date = CURDATE()
      AND check_out_time IS NULL;
END //
DELIMITER ;

-- 29. Submit Leave Request
DELIMITER //
CREATE PROCEDURE SubmitLeaveRequest(
    IN p_user_id INT,
    IN p_leave_type ENUM('Sick', 'Casual', 'Earned', 'Maternity', 'Paternity', 'Emergency'),
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_reason TEXT,
    OUT p_request_id INT
)
BEGIN
    INSERT INTO leave_requests (user_id, leave_type, start_date, end_date, reason, status)
    VALUES (p_user_id, p_leave_type, p_start_date, p_end_date, p_reason, 'Pending');
    
    SET p_request_id = LAST_INSERT_ID();
END //
DELIMITER ;

-- 30. Approve/Reject Leave Request
DELIMITER //
CREATE PROCEDURE ProcessLeaveRequest(
    IN p_leave_id INT,
    IN p_approver_id INT,
    IN p_new_status ENUM('Approved', 'Rejected')
)
BEGIN
    UPDATE leave_requests 
    SET status = p_new_status,
        approved_by = p_approver_id
    WHERE leave_id = p_leave_id AND status = 'Pending';
END //
DELIMITER ;

-- 31. Add Patient Feedback
DELIMITER //
CREATE PROCEDURE AddPatientFeedback(
    IN p_patient_id INT,
    IN p_appointment_id INT,
    IN p_rating INT,
    IN p_category ENUM('Doctor', 'Service', 'Facility', 'Billing', 'Staff', 'General'),
    IN p_comments TEXT,
    IN p_is_anonymous BOOLEAN
)
BEGIN
    IF p_rating BETWEEN 1 AND 5 THEN
        INSERT INTO patient_feedback (
            patient_id, appointment_id, rating, feedback_category, 
            comments, is_anonymous
        ) VALUES (
            p_patient_id, p_appointment_id, p_rating, p_category,
            p_comments, p_is_anonymous
        );
    END IF;
END //
DELIMITER ;

-- 32. Create Hospital Announcement
DELIMITER //
CREATE PROCEDURE CreateAnnouncement(
    IN p_title VARCHAR(200),
    IN p_content TEXT,
    IN p_target_audience ENUM('All', 'Doctors', 'Patients', 'Staff', 'Admin'),
    IN p_priority ENUM('Low', 'Medium', 'High', 'Urgent'),
    IN p_created_by INT,
    IN p_expiry_days INT
)
BEGIN
    DECLARE v_expiry_date DATETIME;
    
    IF p_expiry_days > 0 THEN
        SET v_expiry_date = DATE_ADD(NOW(), INTERVAL p_expiry_days DAY);
    ELSE
        SET v_expiry_date = NULL;
    END IF;
    
    INSERT INTO announcements (
        title, content, target_audience, priority, 
        created_by, expiry_date
    ) VALUES (
        p_title, p_content, p_target_audience, p_priority,
        p_created_by, v_expiry_date
    );
END //
DELIMITER ;

-- 33. Track Medical Supply Usage
DELIMITER //
CREATE PROCEDURE RecordSupplyUsage(
    IN p_supply_id INT,
    IN p_quantity INT,
    IN p_dept_id INT,
    IN p_patient_id INT,
    IN p_recorded_by INT,
    IN p_remarks TEXT
)
BEGIN
    INSERT INTO supply_usage_log (
        supply_id, quantity_used, used_by_dept_id, 
        used_for_patient_id, recorded_by, remarks
    ) VALUES (
        p_supply_id, p_quantity, p_dept_id,
        p_patient_id, p_recorded_by, p_remarks
    );
    
    UPDATE medical_supplies 
    SET current_stock = current_stock - p_quantity
    WHERE supply_id = p_supply_id;
END //
DELIMITER ;

-- 34. Check Blood Availability
DELIMITER //
CREATE FUNCTION CheckBloodAvailability(
    p_blood_type VARCHAR(5),
    p_rh_factor ENUM('Positive', 'Negative')
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE available_units INT;
    
    SELECT COALESCE(SUM(units_available), 0) INTO available_units
    FROM blood_bank
    WHERE blood_type = p_blood_type
      AND rh_factor = p_rh_factor
      AND status = 'Available'
      AND expiry_date > CURDATE();
    
    RETURN available_units;
END //
DELIMITER ;

-- 35. Record Blood Transfusion
DELIMITER //
CREATE PROCEDURE RecordBloodTransfusion(
    IN p_patient_id INT,
    IN p_blood_id INT,
    IN p_doctor_id INT,
    IN p_units_transfused DECIMAL(5,2),
    IN p_reaction_observed BOOLEAN,
    IN p_reaction_notes TEXT
)
BEGIN
    INSERT INTO blood_transfusions (
        patient_id, blood_id, doctor_id, transfusion_date,
        units_transfused, reaction_observed, reaction_notes
    ) VALUES (
        p_patient_id, p_blood_id, p_doctor_id, NOW(),
        p_units_transfused, p_reaction_observed, p_reaction_notes
    );
    
    UPDATE blood_bank 
    SET units_available = units_available - p_units_transfused,
        status = IF(units_available - p_units_transfused <= 0, 'Used', 'Available')
    WHERE blood_id = p_blood_id;
END //
DELIMITER ;

-- 36. Schedule Ambulance Service
DELIMITER //
CREATE PROCEDURE ScheduleAmbulanceService(
    IN p_ambulance_id INT,
    IN p_patient_id INT,
    IN p_pickup_location TEXT,
    IN p_dropoff_location TEXT,
    IN p_emergency_type VARCHAR(100),
    OUT p_service_id INT
)
BEGIN
    DECLARE v_available INT;
    
    SELECT COUNT(*) INTO v_available
    FROM ambulance_fleet
    WHERE ambulance_id = p_ambulance_id
      AND current_status = 'Available';
    
    IF v_available > 0 THEN
        INSERT INTO ambulance_service_logs (
            ambulance_id, patient_id, pickup_location, 
            dropoff_location, service_date, emergency_type
        ) VALUES (
            p_ambulance_id, p_patient_id, p_pickup_location,
            p_dropoff_location, NOW(), p_emergency_type
        );
        
        SET p_service_id = LAST_INSERT_ID();
        
        UPDATE ambulance_fleet 
        SET current_status = 'On_Duty'
        WHERE ambulance_id = p_ambulance_id;
    ELSE
        SET p_service_id = NULL;
    END IF;
END //
DELIMITER ;

-- 37. Complete Ambulance Service
DELIMITER //
CREATE PROCEDURE CompleteAmbulanceService(
    IN p_service_id INT,
    IN p_distance_km DECIMAL(8,2),
    IN p_charge_amount DECIMAL(10,2)
)
BEGIN
    DECLARE v_ambulance_id INT;
    
    SELECT ambulance_id INTO v_ambulance_id
    FROM ambulance_service_logs
    WHERE service_id = p_service_id;
    
    UPDATE ambulance_service_logs 
    SET completion_time = NOW(),
        distance_km = p_distance_km,
        charge_amount = p_charge_amount
    WHERE service_id = p_service_id;
    
    UPDATE ambulance_fleet 
    SET current_status = 'Available'
    WHERE ambulance_id = v_ambulance_id;
END //
DELIMITER ;

-- 38. Add Vaccination Record
DELIMITER //
CREATE PROCEDURE AddVaccinationRecord(
    IN p_patient_id INT,
    IN p_vaccine_name VARCHAR(100),
    IN p_dose_number INT,
    IN p_administered_by INT,
    IN p_batch_number VARCHAR(50),
    IN p_manufacturer VARCHAR(100),
    IN p_next_dose_days INT
)
BEGIN
    DECLARE v_next_dose DATE;
    
    IF p_next_dose_days > 0 THEN
        SET v_next_dose = DATE_ADD(CURDATE(), INTERVAL p_next_dose_days DAY);
    ELSE
        SET v_next_dose = NULL;
    END IF;
    
    INSERT INTO vaccination_records (
        patient_id, vaccine_name, dose_number, vaccination_date,
        administered_by, batch_number, manufacturer, next_dose_date
    ) VALUES (
        p_patient_id, p_vaccine_name, p_dose_number, CURDATE(),
        p_administered_by, p_batch_number, p_manufacturer, v_next_dose
    );
END //
DELIMITER ;

-- 39. Get Staff Attendance Report
DELIMITER //
CREATE PROCEDURE GetStaffAttendanceReport(
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_user_id INT
)
BEGIN
    SELECT 
        sa.attendance_date,
        sa.check_in_time,
        sa.check_out_time,
        sa.status,
        TIMESTAMPDIFF(HOUR, sa.check_in_time, sa.check_out_time) AS hours_worked,
        u.email,
        CONCAT(p.first_name, ' ', p.last_name) AS full_name
    FROM staff_attendance sa
    JOIN users u ON sa.user_id = u.user_id
    JOIN profiles p ON u.user_id = p.user_id
    WHERE sa.user_id = p_user_id
      AND sa.attendance_date BETWEEN p_start_date AND p_end_date
    ORDER BY sa.attendance_date DESC;
END //
DELIMITER ;

-- 40. Calculate Average Patient Satisfaction
DELIMITER //
CREATE FUNCTION CalculateAverageSatisfaction(
    p_category ENUM('Doctor', 'Service', 'Facility', 'Billing', 'Staff', 'General')
)
RETURNS DECIMAL(3,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE avg_rating DECIMAL(3,2);
    
    SELECT AVG(rating) INTO avg_rating
    FROM patient_feedback
    WHERE feedback_category = p_category;
    
    RETURN IFNULL(avg_rating, 0);
END //
DELIMITER ;

-- =============================================
-- ADDITIONAL TRIGGERS
-- =============================================

-- 41. Auto-expire Blood Units
DELIMITER //
CREATE TRIGGER trg_expire_blood_units
BEFORE UPDATE ON blood_bank
FOR EACH ROW
BEGIN
    IF NEW.expiry_date <= CURDATE() AND OLD.status != 'Expired' THEN
        SET NEW.status = 'Expired';
        SET NEW.units_available = 0;
    END IF;
END //
DELIMITER ;

-- 42. Auto-mark Equipment Maintenance Status
DELIMITER //
CREATE TRIGGER trg_equipment_maintenance_alert
AFTER INSERT ON equipment_maintenance_log
FOR EACH ROW
BEGIN
    UPDATE equipment_inventory
    SET current_status = 'Under_Maintenance'
    WHERE equipment_id = NEW.equipment_id;
END //
DELIMITER ;

-- 43. Validate Medical Supply Reorder Level
DELIMITER //
CREATE TRIGGER trg_supply_reorder_alert
AFTER UPDATE ON medical_supplies
FOR EACH ROW
BEGIN
    IF NEW.current_stock <= NEW.reorder_level AND OLD.current_stock > OLD.reorder_level THEN
        INSERT INTO announcements (title, content, target_audience, priority, created_by)
        VALUES (
            CONCAT('Low Stock Alert: ', NEW.supply_name),
            CONCAT('Supply ', NEW.supply_name, ' is running low. Current stock: ', NEW.current_stock),
            'Staff',
            'High',
            1
        );
    END IF;
END //
DELIMITER ;

-- 44. Auto-deactivate Expired Announcements
DELIMITER //
CREATE TRIGGER trg_expire_announcements
BEFORE UPDATE ON announcements
FOR EACH ROW
BEGIN
    IF NEW.expiry_date IS NOT NULL AND NEW.expiry_date <= NOW() THEN
        SET NEW.is_active = FALSE;
    END IF;
END //
DELIMITER ;

-- 45. Validate Staff Certification Expiry
DELIMITER //
CREATE TRIGGER trg_certification_expiry_alert
AFTER UPDATE ON staff_certifications
FOR EACH ROW
BEGIN
    IF NEW.expiry_date IS NOT NULL 
       AND DATEDIFF(NEW.expiry_date, CURDATE()) <= 30 
       AND DATEDIFF(NEW.expiry_date, CURDATE()) > 0 THEN
        INSERT INTO announcements (title, content, target_audience, priority, created_by)
        VALUES (
            'Certification Expiring Soon',
            CONCAT('Certification ', NEW.certification_name, ' expires on ', NEW.expiry_date),
            'Staff',
            'Medium',
            1
        );
    END IF;
END //
DELIMITER ;



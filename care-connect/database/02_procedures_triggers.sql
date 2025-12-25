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

-- 17. Auto-Generate Invoice for Paid Tests
DELIMITER //
CREATE TRIGGER trg_create_test_invoice
AFTER INSERT ON patient_tests
FOR EACH ROW
BEGIN
    DECLARE test_cost DECIMAL(10, 2);
    
    -- Only create invoice if payment is PAID
    IF NEW.payment_status = 'PAID' THEN
        -- Get test cost
        SELECT cost INTO test_cost FROM medical_tests WHERE test_id = NEW.test_id;
        
        -- Create invoice
        INSERT INTO invoices (test_record_id, total_amount, discount_amount, net_amount, status, generated_at)
        VALUES (NEW.record_id, test_cost, 0.00, test_cost, 'Paid', NOW());
    END IF;
END //
DELIMITER ;


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



USE careconnect;

DROP PROCEDURE IF EXISTS DischargePatient;

DELIMITER //

CREATE PROCEDURE DischargePatient(
    IN p_admission_id INT,
    OUT p_total_bill DECIMAL(10, 2),
    OUT p_invoice_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_room_number VARCHAR(20);
    DECLARE v_daily_rate DECIMAL(10, 2);
    DECLARE v_admission_time TIMESTAMP;
    DECLARE v_discharge_time TIMESTAMP;
    DECLARE v_days_stayed INT;
    DECLARE v_patient_id INT;
    DECLARE v_already_discharged INT;

    -- Check if admission exists and is active
    SELECT COUNT(*)
    INTO v_already_discharged
    FROM admissions
    WHERE admission_id = p_admission_id;

    IF v_already_discharged = 0 THEN
        SET p_message = 'Admission record not found.';
    ELSE
        -- Get admission details
        SELECT room_number, admission_date, patient_id
        INTO v_room_number, v_admission_time, v_patient_id
        FROM admissions
        WHERE admission_id = p_admission_id;
        
        -- Check if already discharged
        IF (SELECT status FROM admissions WHERE admission_id = p_admission_id) = 'Discharged' THEN
            SET p_message = 'Patient is already discharged.';
        ELSE
            -- 1. Calculate Duration and Cost
            SET v_discharge_time = NOW();
            
            -- Get Room Rate
            SELECT charge_per_day INTO v_daily_rate FROM rooms WHERE room_number = v_room_number;

            -- Calculate Days (Ceil logic: even 1 hour counts as a day for simplicity, or 24h blocks)
            -- Using simple DATEDIFF + 1 for inclusive billing
            SET v_days_stayed = DATEDIFF(v_discharge_time, v_admission_time);
            
            IF v_days_stayed < 1 THEN
                SET v_days_stayed = 1;
            END IF;

            SET p_total_bill = v_days_stayed * v_daily_rate;

            -- 2. Update Admission Record
            UPDATE admissions 
            SET discharge_date = v_discharge_time,
                total_cost = p_total_bill,
                status = 'Discharged',
                payment_status = 'Pending' -- Invoice will be created
            WHERE admission_id = p_admission_id;

            -- 3. Free up the Room
            UPDATE rooms 
            SET is_available = TRUE 
            WHERE room_number = v_room_number;

            -- 4. Create Invoice
            INSERT INTO invoices (admission_id, total_amount, net_amount, status)
            VALUES (p_admission_id, p_total_bill, p_total_bill, 'Unpaid');
            
            SET p_invoice_id = LAST_INSERT_ID();
            SET p_message = 'Discharge successful. Invoice generated.';

        END IF;
    END IF;
END //

DELIMITER ;

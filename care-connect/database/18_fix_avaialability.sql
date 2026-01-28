USE careconnect;

DELIMITER //

DROP FUNCTION IF EXISTS IsDoctorAvailable //

CREATE FUNCTION IsDoctorAvailable(doc_id INT, appt_datetime DATETIME)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE conflict_count INT;
    DECLARE day_name VARCHAR(15);
    DECLARE schedule_exists INT;
    DECLARE daily_appt_count INT;
    DECLARE on_leave INT;
    DECLARE MAX_APPOINTMENTS_PER_DAY INT DEFAULT 5; -- Business Rule: Max 5 bookings per doctor per day

    -- 0. Check if Doctor is on Leave
    SELECT COUNT(*) INTO on_leave
    FROM doctor_leaves
    WHERE doctor_id = doc_id
      AND DATE(appt_datetime) BETWEEN start_date AND end_date;

    IF on_leave > 0 THEN
        RETURN FALSE;
    END IF;

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

    -- 2. Check Capacity Limit (Max 5 per day)
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

DROP PROCEDURE IF EXISTS GetDoctorSlots //

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
    DECLARE v_on_leave INT;
    
    -- 0. Check if on Leave
    SELECT COUNT(*) INTO v_on_leave
    FROM doctor_leaves
    WHERE doctor_id = p_doctor_id
      AND DATE(p_date) BETWEEN start_date AND end_date;
      
    IF v_on_leave > 0 THEN
        SET p_is_available = FALSE;
        SET p_message = 'Doctor is on leave for this date.';
        SET p_remaining_slots = 0;
    ELSE
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
    END IF;
END //

DELIMITER ;

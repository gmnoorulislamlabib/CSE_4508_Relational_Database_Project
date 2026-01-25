USE careconnect;

DELIMITER //

-- Update IsDoctorAvailable Function to respect Leave Periods
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
    DECLARE MAX_APPOINTMENTS_PER_DAY INT DEFAULT 5; -- Business Rule: Max 5 bookings per doctor per day

    -- 0. Check for Leave (Updated for date ranges)
    SELECT COUNT(*) INTO conflict_count 
    FROM doctor_leaves 
    WHERE doctor_id = doc_id 
      AND DATE(appt_datetime) BETWEEN start_date AND end_date;
      
    IF conflict_count > 0 THEN
        RETURN FALSE; -- Doctor is on leave
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

-- Update GetAvailableTimeSlots Procedure to respect Leave Periods
DROP PROCEDURE IF EXISTS GetAvailableTimeSlots //

CREATE PROCEDURE GetAvailableTimeSlots(
    IN p_doctor_id INT,
    IN p_date DATE
)
BEGIN
    DECLARE v_start_time TIME;
    DECLARE v_end_time TIME;
    DECLARE v_day_name VARCHAR(15);
    DECLARE v_current_slot DATETIME;
    DECLARE v_slot_time TIME;
    DECLARE v_is_available BOOLEAN;
    DECLARE v_on_leave INT;

    -- Temp table to store slots
    DROP TEMPORARY TABLE IF EXISTS temp_slots;
    CREATE TEMPORARY TABLE temp_slots (
        slot_time TIME,
        is_available BOOLEAN
    );

    -- 0. Check if on Leave (Updated for date ranges)
    SELECT COUNT(*) INTO v_on_leave 
    FROM doctor_leaves 
    WHERE doctor_id = p_doctor_id 
      AND p_date BETWEEN start_date AND end_date;

    IF v_on_leave > 0 THEN
        -- Return empty set or special message? Just empty set means no slots.
        SELECT * FROM temp_slots;
        -- Implicitly returns empty
    ELSE
        -- 1. Get Schedule for the requested Day
        SET v_day_name = DAYNAME(p_date);
        
        SELECT start_time, end_time INTO v_start_time, v_end_time
        FROM schedules
        WHERE doctor_id = p_doctor_id AND day_of_week = v_day_name
        LIMIT 1;

        IF v_start_time IS NOT NULL THEN
            -- 2. Generate slots (every 30 mins)
            SET v_current_slot = CAST(CONCAT(p_date, ' ', v_start_time) AS DATETIME);
            
            WHILE TIME(v_current_slot) < v_end_time DO
                SET v_slot_time = TIME(v_current_slot);
                
                -- Check availability using our function (which checks leaves and capacity)
                SET v_is_available = IsDoctorAvailable(p_doctor_id, v_current_slot);
                
                INSERT INTO temp_slots VALUES (v_slot_time, v_is_available);
                
                SET v_current_slot = DATE_ADD(v_current_slot, INTERVAL 30 MINUTE);
            END WHILE;
        END IF;

        SELECT * FROM temp_slots;
    END IF;
END //

DELIMITER ;

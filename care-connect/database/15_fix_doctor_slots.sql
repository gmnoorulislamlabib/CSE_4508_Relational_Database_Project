USE careconnect;

-- Update GetDoctorSlots Procedure to respect Leave Periods
DROP PROCEDURE IF EXISTS GetDoctorSlots;

DELIMITER //

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
    DECLARE v_leave_count INT;
    
    -- 0. Check for Leave FIRST
    SELECT COUNT(*) INTO v_leave_count 
    FROM doctor_leaves 
    WHERE doctor_id = p_doctor_id 
      AND DATE(p_date) BETWEEN start_date AND end_date;

    IF v_leave_count > 0 THEN
        SET p_is_available = FALSE;
        SET p_message = 'Doctor is on leave.';
        SET p_remaining_slots = 0;
    ELSE
        -- 1. Check Schedule (Day & Time)
        SET v_day_name = DAYNAME(p_date);
        
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

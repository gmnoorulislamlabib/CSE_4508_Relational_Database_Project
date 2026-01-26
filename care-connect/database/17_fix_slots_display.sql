USE careconnect;

DELIMITER //

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

    -- 0. Check if on Leave
    SELECT COUNT(*) INTO v_on_leave 
    FROM doctor_leaves 
    WHERE doctor_id = p_doctor_id 
      AND p_date BETWEEN start_date AND end_date;

    IF v_on_leave > 0 THEN
        SELECT slot_time, DATE_FORMAT(slot_time, '%l:%i %p') as formatted_time 
        FROM temp_slots; 
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
                
                -- Check availability
                SET v_is_available = IsDoctorAvailable(p_doctor_id, v_current_slot);
                
                IF v_is_available THEN
                    INSERT INTO temp_slots VALUES (v_slot_time, TRUE);
                END IF;
                
                SET v_current_slot = DATE_ADD(v_current_slot, INTERVAL 30 MINUTE);
            END WHILE;
        END IF;

        SELECT slot_time, DATE_FORMAT(slot_time, '%l:%i %p') as formatted_time 
        FROM temp_slots;
    END IF;
END //

DELIMITER ;

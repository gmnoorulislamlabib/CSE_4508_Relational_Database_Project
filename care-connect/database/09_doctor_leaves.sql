USE careconnect;

-- 1. Create Doctor Leaves Table (Updated for Date Ranges)
DROP TABLE IF EXISTS doctor_leaves;

CREATE TABLE doctor_leaves (
    leave_id INT AUTO_INCREMENT PRIMARY KEY,
    doctor_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    CHECK (end_date >= start_date)
);

DROP PROCEDURE IF EXISTS AddDoctorLeave;

DELIMITER //

CREATE PROCEDURE AddDoctorLeave(
    IN p_doctor_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_reason VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_count INT;
    DECLARE v_cancelled_count INT DEFAULT 0;

    -- Check if doctor exists
    SELECT COUNT(*) INTO v_count FROM doctors WHERE doctor_id = p_doctor_id;
    
    IF v_count = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'Doctor not found.';
    ELSEIF p_end_date < p_start_date THEN
        SET p_success = FALSE;
        SET p_message = 'End date must be on or after start date.';
    ELSE
        -- Check for overlapping leaves
        SELECT COUNT(*) INTO v_count 
        FROM doctor_leaves 
        WHERE doctor_id = p_doctor_id 
          AND (
              (p_start_date BETWEEN start_date AND end_date) OR
              (p_end_date BETWEEN start_date AND end_date) OR
              (start_date BETWEEN p_start_date AND p_end_date)
          );
        
        IF v_count > 0 THEN
            SET p_success = FALSE;
            SET p_message = 'Leave period overlaps with existing leave.';
        ELSE
            -- Insert Leave Period
            INSERT INTO doctor_leaves (doctor_id, start_date, end_date, reason)
            VALUES (p_doctor_id, p_start_date, p_end_date, p_reason);
            
            -- Cancel any appointments during this leave period
            UPDATE appointments 
            SET status = 'Cancelled', 
                reason = CONCAT('Doctor on leave: ', IFNULL(p_reason, 'Not specified'))
            WHERE doctor_id = p_doctor_id 
              AND DATE(appointment_date) BETWEEN p_start_date AND p_end_date
              AND status IN ('Scheduled', 'Confirmed', 'Pending_Payment');
            
            SET v_cancelled_count = ROW_COUNT();
            SET p_success = TRUE;
            SET p_message = CONCAT('Leave added successfully. ', v_cancelled_count, ' conflicting appointment(s) cancelled.');
        END IF;
    END IF;
END //

DELIMITER ;

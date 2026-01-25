USE careconnect;

-- 1. Create Staff Leaves Table
CREATE TABLE IF NOT EXISTS staff_leaves (
    leave_id INT AUTO_INCREMENT PRIMARY KEY,
    staff_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON DELETE CASCADE,
    CHECK (end_date >= start_date)
);

-- 2. Procedure to Add Staff Leave
DROP PROCEDURE IF EXISTS AddStaffLeave;

DELIMITER //

CREATE PROCEDURE AddStaffLeave(
    IN p_staff_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_reason VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_count INT;

    -- Check if staff exists
    SELECT COUNT(*) INTO v_count FROM staff WHERE staff_id = p_staff_id;
    
    IF v_count = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'Staff member not found.';
    ELSEIF p_end_date < p_start_date THEN
        SET p_success = FALSE;
        SET p_message = 'End date must be on or after start date.';
    ELSE
        -- Check for overlapping leaves
        SELECT COUNT(*) INTO v_count 
        FROM staff_leaves 
        WHERE staff_id = p_staff_id 
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
            INSERT INTO staff_leaves (staff_id, start_date, end_date, reason)
            VALUES (p_staff_id, p_start_date, p_end_date, p_reason);
            
            SET p_success = TRUE;
            SET p_message = 'Staff leave added successfully.';
        END IF;
    END IF;
END //

DELIMITER ;

-- 3. Update View_ActiveDoctors to exclude those on leave TODAY
CREATE OR REPLACE VIEW View_ActiveDoctors AS
SELECT 
    d.doctor_id,
    CONCAT(p.first_name, ' ', p.last_name) AS doctor_name,
    dept.name AS department_name,
    d.specialization,
    GROUP_CONCAT(DISTINCT COALESCE(r.room_number, s.room_number) ORDER BY r.room_number SEPARATOR ', ') AS room_numbers
FROM doctors d
JOIN profiles p ON d.user_id = p.user_id
JOIN departments dept ON d.dept_id = dept.dept_id
LEFT JOIN schedules s ON d.doctor_id = s.doctor_id
LEFT JOIN rooms r ON r.current_doctor_id = d.doctor_id
WHERE d.doctor_id NOT IN (
    SELECT doctor_id FROM doctor_leaves 
    WHERE CURDATE() BETWEEN start_date AND end_date
)
GROUP BY d.doctor_id, doctor_name, department_name, d.specialization;

-- 4. Create View_DoctorsOnLeave
CREATE OR REPLACE VIEW View_DoctorsOnLeave AS
SELECT 
    d.doctor_id,
    CONCAT(p.first_name, ' ', p.last_name) AS doctor_name,
    dept.name AS department_name,
    dl.start_date,
    dl.end_date,
    dl.reason
FROM doctor_leaves dl
JOIN doctors d ON dl.doctor_id = d.doctor_id
JOIN profiles p ON d.user_id = p.user_id
JOIN departments dept ON d.dept_id = dept.dept_id
WHERE CURDATE() BETWEEN dl.start_date AND dl.end_date;

-- 5. Create View_ActiveStaff (Excluding leaves)
CREATE OR REPLACE VIEW View_ActiveStaff AS
SELECT 
    s.staff_id,
    CONCAT(p.first_name, ' ', p.last_name) AS staff_name,
    s.job_title,
    dept.name AS department_name,
    s.shift
FROM staff s
JOIN profiles p ON s.user_id = p.user_id
LEFT JOIN departments dept ON s.dept_id = dept.dept_id
WHERE s.staff_id NOT IN (
    SELECT staff_id FROM staff_leaves 
    WHERE CURDATE() BETWEEN start_date AND end_date
);

-- 6. Create View_StaffOnLeave
CREATE OR REPLACE VIEW View_StaffOnLeave AS
SELECT 
    s.staff_id,
    CONCAT(p.first_name, ' ', p.last_name) AS staff_name,
    s.job_title,
    dept.name AS department_name,
    sl.start_date,
    sl.end_date,
    sl.reason
FROM staff_leaves sl
JOIN staff s ON sl.staff_id = s.staff_id
JOIN profiles p ON s.user_id = p.user_id
LEFT JOIN departments dept ON s.dept_id = dept.dept_id
WHERE CURDATE() BETWEEN sl.start_date AND sl.end_date;

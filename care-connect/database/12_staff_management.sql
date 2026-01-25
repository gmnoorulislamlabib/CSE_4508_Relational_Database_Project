USE careconnect;

-- 26. Staff Table (For non-medical staff like HR, Receptionist, Nurse, etc.)
CREATE TABLE IF NOT EXISTS staff (
    staff_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    dept_id INT NULL,
    job_title VARCHAR(100) NOT NULL,
    salary DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    shift ENUM('Day', 'Night', 'Rotational') DEFAULT 'Day',
    joining_date DATE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE SET NULL
);

DROP PROCEDURE IF EXISTS AddStaff;
DROP PROCEDURE IF EXISTS UpdateStaffDetails;

DELIMITER //

-- Procedure to Add New Staff (Creates User + Staff Profile)
CREATE PROCEDURE AddStaff(
    IN p_first_name VARCHAR(50),
    IN p_last_name VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_password VARCHAR(255),
    IN p_phone VARCHAR(20),
    IN p_gender ENUM('Male', 'Female', 'Other'),
    IN p_dept_id INT,
    IN p_job_title VARCHAR(100),
    IN p_salary DECIMAL(10, 2),
    IN p_shift ENUM('Day', 'Night', 'Rotational'),
    IN p_joining_date DATE
)
BEGIN
    DECLARE new_user_id INT;
    
    START TRANSACTION;
    
    -- 1. Create User
    INSERT INTO users (email, password_hash, role, is_active)
    VALUES (p_email, p_password, 'Staff', TRUE);
    
    SET new_user_id = LAST_INSERT_ID();
    
    -- 2. Create Profile
    INSERT INTO profiles (user_id, first_name, last_name, phone_number, gender)
    VALUES (new_user_id, p_first_name, p_last_name, p_phone, p_gender);
    
    -- 3. Create Staff Record
    INSERT INTO staff (user_id, dept_id, job_title, salary, shift, joining_date)
    VALUES (new_user_id, p_dept_id, p_job_title, p_salary, p_shift, p_joining_date);
    
    COMMIT;
END //

-- Procedure to Update Staff Details
CREATE PROCEDURE UpdateStaffDetails(
    IN p_staff_id INT,
    IN p_job_title VARCHAR(100),
    IN p_salary DECIMAL(10, 2),
    IN p_shift ENUM('Day', 'Night', 'Rotational'),
    IN p_dept_id INT
)
BEGIN
    UPDATE staff
    SET job_title = p_job_title,
        salary = p_salary,
        shift = p_shift,
        dept_id = p_dept_id
    WHERE staff_id = p_staff_id;
END //

DELIMITER ;

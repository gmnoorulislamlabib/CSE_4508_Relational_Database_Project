USE careconnect;

-- Seed Staff Data
-- Note: These will be inserted after the staff table and AddStaff procedure are created

-- HR Staff
CALL AddStaff('Sarah', 'Johnson', 'sarah.johnson@careconnect.com', 'staff123', '+8801712345678', 'Female', 
              NULL, 'HR Manager', 45000.00, 'Day', '2024-01-15');

CALL AddStaff('Michael', 'Chen', 'michael.chen@careconnect.com', 'staff123', '+8801723456789', 'Male', 
              NULL, 'HR Assistant', 30000.00, 'Day', '2024-03-01');

-- Nursing Staff
CALL AddStaff('Emily', 'Rahman', 'emily.rahman@careconnect.com', 'staff123', '+8801734567890', 'Female', 
              1, 'Head Nurse', 40000.00, 'Day', '2023-06-10');

CALL AddStaff('David', 'Ahmed', 'david.ahmed@careconnect.com', 'staff123', '+8801745678901', 'Male', 
              2, 'ICU Nurse', 38000.00, 'Night', '2023-09-20');

CALL AddStaff('Lisa', 'Khan', 'lisa.khan@careconnect.com', 'staff123', '+8801756789012', 'Female', 
              3, 'Pediatric Nurse', 36000.00, 'Rotational', '2024-02-14');

-- Reception Staff
CALL AddStaff('James', 'Hossain', 'james.hossain@careconnect.com', 'staff123', '+8801767890123', 'Male', 
              NULL, 'Senior Receptionist', 28000.00, 'Day', '2023-11-05');

CALL AddStaff('Maria', 'Islam', 'maria.islam@careconnect.com', 'staff123', '+8801778901234', 'Female', 
              NULL, 'Receptionist', 25000.00, 'Night', '2024-04-18');

-- Lab Technicians
CALL AddStaff('Robert', 'Das', 'robert.das@careconnect.com', 'staff123', '+8801789012345', 'Male', 
              4, 'Senior Lab Technician', 42000.00, 'Day', '2022-08-12');

CALL AddStaff('Jennifer', 'Roy', 'jennifer.roy@careconnect.com', 'staff123', '+8801790123456', 'Female', 
              4, 'Lab Technician', 35000.00, 'Rotational', '2023-12-03');

-- Pharmacy Staff
CALL AddStaff('William', 'Chowdhury', 'william.chowdhury@careconnect.com', 'staff123', '+8801701234567', 'Male', 
              NULL, 'Pharmacist', 48000.00, 'Day', '2023-05-22');

CALL AddStaff('Patricia', 'Begum', 'patricia.begum@careconnect.com', 'staff123', '+8801712345679', 'Female', 
              NULL, 'Pharmacy Assistant', 32000.00, 'Night', '2024-01-30');

-- Ward Boys / Support Staff
CALL AddStaff('Thomas', 'Miah', 'thomas.miah@careconnect.com', 'staff123', '+8801723456780', 'Male', 
              NULL, 'Ward Boy', 22000.00, 'Day', '2024-02-10');

CALL AddStaff('Linda', 'Akter', 'linda.akter@careconnect.com', 'staff123', '+8801734567891', 'Female', 
              NULL, 'Cleaning Staff', 20000.00, 'Night', '2024-03-15');

-- IT Support
CALL AddStaff('Christopher', 'Karim', 'christopher.karim@careconnect.com', 'staff123', '+8801745678902', 'Male', 
              NULL, 'IT Support Specialist', 50000.00, 'Day', '2023-07-08');

-- Administrative
CALL AddStaff('Barbara', 'Sultana', 'barbara.sultana@careconnect.com', 'staff123', '+8801756789013', 'Female', 
              NULL, 'Administrative Officer', 38000.00, 'Day', '2023-10-25');

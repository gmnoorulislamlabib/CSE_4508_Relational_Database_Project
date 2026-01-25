USE careconnect;

DROP PROCEDURE IF EXISTS CreateConsultationRecord;

DELIMITER //

CREATE PROCEDURE CreateConsultationRecord(
    IN p_appointment_id INT,
    IN p_diagnosis TEXT,
    IN p_symptoms TEXT,
    IN p_treatment_plan TEXT,
    -- Simple Vitals as JSON string
    IN p_vitals JSON,
    -- Output
    OUT p_record_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_count INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Database error during consultation creation.';
        -- GET DIAGNOSTICS CONDITION 1 @text = MESSAGE_TEXT;
        -- SET p_message = CONCAT('Error: ', @text); -- Optional debug
    END;

    START TRANSACTION;

    -- Check if appointment exists
    SELECT COUNT(*) INTO v_count FROM appointments WHERE appointment_id = p_appointment_id;

    IF v_count = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'Appointment not found.';
        ROLLBACK;
    ELSE
        -- 1. Create Medical Record
        INSERT INTO medical_records (appointment_id, diagnosis, symptoms, treatment_plan, vitals)
        VALUES (p_appointment_id, p_diagnosis, p_symptoms, p_treatment_plan, p_vitals);
        
        SET p_record_id = LAST_INSERT_ID();

        -- 2. Update Appointment Status to Completed
        UPDATE appointments SET status = 'Completed' WHERE appointment_id = p_appointment_id;

        -- 3. Create Empty Prescription Header (Items added separately or passed in JSON in more complex version)
        -- For this demo, we assume items are added via separate calls or we'll add logic here if we passed JSON.
        -- Let's auto-create a prescription record to attach items to.
        INSERT INTO prescriptions (record_id, notes) VALUES (p_record_id, 'Generated from Consultation');
        
        COMMIT;
        SET p_success = TRUE;
        SET p_message = 'Consultation record created successfully.';
    END IF;
END //

-- Procedure to Add Items to Prescription
DROP PROCEDURE IF EXISTS AddPrescriptionItem //

CREATE PROCEDURE AddPrescriptionItem(
    IN p_record_id INT,
    IN p_medicine_id INT,
    IN p_dosage VARCHAR(50),
    IN p_frequency VARCHAR(50),
    IN p_duration INT
)
BEGIN
    DECLARE v_presc_id INT;
    
    -- Get Prescription ID from Record
    SELECT prescription_id INTO v_presc_id FROM prescriptions WHERE record_id = p_record_id LIMIT 1;
    
    IF v_presc_id IS NOT NULL THEN
        INSERT INTO prescription_items (prescription_id, medicine_id, dosage, frequency, duration_days)
        VALUES (v_presc_id, p_medicine_id, p_dosage, p_frequency, p_duration);
    END IF;
END //

DELIMITER ;

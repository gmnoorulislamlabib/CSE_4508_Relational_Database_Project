USE careconnect;

-- This trigger is applied AFTER seeding to avoid conflict with manually seeded historical invoices.

DELIMITER //
CREATE TRIGGER trg_create_test_invoice
AFTER INSERT ON patient_tests
FOR EACH ROW
BEGIN
    DECLARE test_cost DECIMAL(10, 2);
    
    -- Only create invoice if payment is PAID
    IF NEW.payment_status = 'PAID' THEN
        -- Get test cost
        SELECT cost INTO test_cost FROM medical_tests WHERE test_id = NEW.test_id;
        
        -- Create invoice
        INSERT INTO invoices (test_record_id, total_amount, discount_amount, net_amount, status, generated_at)
        VALUES (NEW.record_id, test_cost, 0.00, test_cost, 'Paid', NOW());
    END IF;
END //
DELIMITER ;

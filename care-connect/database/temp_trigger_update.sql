USE careconnect;

DROP TRIGGER IF EXISTS trg_invoice_paid_schedule_appointment;

DELIMITER //

CREATE TRIGGER trg_invoice_paid_schedule_appointment
AFTER UPDATE ON invoices
FOR EACH ROW
BEGIN
    IF NEW.status = 'Paid' AND OLD.status != 'Paid' AND NEW.appointment_id IS NOT NULL THEN
        UPDATE appointments 
        SET status = 'Scheduled' 
        WHERE appointment_id = NEW.appointment_id AND status = 'Pending_Payment';
    END IF;
END //

DELIMITER ;

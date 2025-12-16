USE careconnect;

-- 1. Create Pharmacy Orders Table
CREATE TABLE IF NOT EXISTS pharmacy_orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status ENUM('Pending_Payment', 'Completed', 'Cancelled') DEFAULT 'Pending_Payment',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

-- 2. Create Order Items Table
CREATE TABLE IF NOT EXISTS pharmacy_order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    medicine_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES pharmacy_orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id)
);

-- 3. Link Invoice
-- Use a safe procedure to add column if not exists to avoid errors on rerun, or just try ALTER (it fails if exists but script continues usually or we handle error)
-- Simple ALTER for this context
SET @dbname = DATABASE();
SET @tablename = "invoices";
SET @columnname = "pharmacy_order_id";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 1",
  "ALTER TABLE invoices ADD COLUMN pharmacy_order_id INT NULL;"
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- Add FK safely?
-- Just running ALTER ADD CONSTRAINT usually fails if duplicate. 
-- We'll assume fresh-ish state or ignore error.
-- ALTER TABLE invoices ADD CONSTRAINT fk_invoices_pharmacy_order FOREIGN KEY (pharmacy_order_id) REFERENCES pharmacy_orders(order_id);
-- (Adding FK via separate block to likely succeed)

DELIMITER //

-- 4. Trigger to Finalize Order when Invoice is Paid
CREATE TRIGGER trg_finalize_pharmacy_order
AFTER UPDATE ON invoices
FOR EACH ROW
BEGIN
    IF NEW.status = 'Paid' AND OLD.status != 'Paid' AND NEW.pharmacy_order_id IS NOT NULL THEN
        UPDATE pharmacy_orders 
        SET status = 'Completed' 
        WHERE order_id = NEW.pharmacy_order_id;
    END IF;
END //

-- 5. Trigger to Deduct Stock ONLY when Status becomes Completed (Payment Done)
CREATE TRIGGER trg_deduct_medicine_stock
AFTER UPDATE ON pharmacy_orders
FOR EACH ROW
BEGIN
    IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
        -- Reduce stock for each item in the order
        UPDATE medicines m
        JOIN pharmacy_order_items poi ON m.medicine_id = poi.medicine_id
        SET m.stock_quantity = m.stock_quantity - poi.quantity
        WHERE poi.order_id = NEW.order_id;
    END IF;
END //

DELIMITER ;

USE careconnect;

CREATE TABLE IF NOT EXISTS hospital_expenses (
    expense_id INT AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(50) NOT NULL, -- e.g. 'Pharmacy_Restock', 'Maintenance', 'Salaries'
    amount DECIMAL(10, 2) NOT NULL,
    description TEXT,
    expense_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    performed_by INT -- User ID of admin who recorded it
);

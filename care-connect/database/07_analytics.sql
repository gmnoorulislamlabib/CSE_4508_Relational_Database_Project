/*****************************************************************************************
 * DATABASE: careconnect
 * FILE NAME: hospital_earnings_procedures.sql
 * DESCRIPTION:
 *     This script contains stored procedures, views, helper utilities, and
 *     reporting logic for calculating hospital earnings across different
 *     departments and time ranges.
 *
 * AUTHOR: Generated with assistance
 * CREATED DATE: 2026-01-28
 *
 * NOTES:
 *     - This script assumes MySQL 8.x
 *     - Uses defensive programming practices
 *     - Designed for reporting and analytics
 *****************************************************************************************/


/*****************************************************************************************
 * SECTION 1: DATABASE SELECTION
 *****************************************************************************************/
USE careconnect;


/*****************************************************************************************
 * SECTION 2: SUPPORTING TABLES (LOGGING & AUDIT)
 *****************************************************************************************/

-- Table to log procedure executions
CREATE TABLE IF NOT EXISTS procedure_execution_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    procedure_name VARCHAR(100),
    execution_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    start_date DATETIME,
    end_date DATETIME,
    status VARCHAR(20),
    message TEXT
);

-- Table to store error messages
CREATE TABLE IF NOT EXISTS error_log (
    error_id INT AUTO_INCREMENT PRIMARY KEY,
    error_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    procedure_name VARCHAR(100),
    error_message TEXT
);


/*****************************************************************************************
 * SECTION 3: INDEX OPTIMIZATION (PERFORMANCE)
 *****************************************************************************************/

-- Indexes for invoices table
CREATE INDEX IF NOT EXISTS idx_invoices_status_date
ON invoices (status, generated_at);

CREATE INDEX IF NOT EXISTS idx_invoices_appointment
ON invoices (appointment_id);

CREATE INDEX IF NOT EXISTS idx_invoices_test
ON invoices (test_record_id);

CREATE INDEX IF NOT EXISTS idx_invoices_pharmacy
ON invoices (pharmacy_order_id);

-- Indexes for hospital expenses
CREATE INDEX IF NOT EXISTS idx_expenses_category_date
ON hospital_expenses (category, expense_date);


/*****************************************************************************************
 * SECTION 4: HELPER PROCEDURE - LOG EXECUTION
 *****************************************************************************************/
DROP PROCEDURE IF EXISTS LogProcedureExecution;
DELIMITER //
CREATE PROCEDURE LogProcedureExecution(
    IN p_procedure_name VARCHAR(100),
    IN p_start_date DATETIME,
    IN p_end_date DATETIME,
    IN p_status VARCHAR(20),
    IN p_message TEXT
)
BEGIN
    INSERT INTO procedure_execution_log
    (
        procedure_name,
        start_date,
        end_date,
        status,
        message
    )
    VALUES
    (
        p_procedure_name,
        p_start_date,
        p_end_date,
        p_status,
        p_message
    );
END //
DELIMITER ;


 /*****************************************************************************************
 * SECTION 5: HELPER PROCEDURE - ERROR HANDLING
 *****************************************************************************************/
DROP PROCEDURE IF EXISTS LogError;
DELIMITER //
CREATE PROCEDURE LogError(
    IN p_procedure_name VARCHAR(100),
    IN p_error_message TEXT
)
BEGIN
    INSERT INTO error_log
    (
        procedure_name,
        error_message
    )
    VALUES
    (
        p_procedure_name,
        p_error_message
    );
END //
DELIMITER ;


 /*****************************************************************************************
 * SECTION 6: MAIN PROCEDURE - TOTAL EARNINGS
 *****************************************************************************************/
DROP PROCEDURE IF EXISTS GetTotalEarnings;
DELIMITER //
CREATE PROCEDURE GetTotalEarnings(
    IN p_start_date DATETIME,
    IN p_end_date DATETIME
)
BEGIN
    DECLARE v_total_invoices DECIMAL(15,2) DEFAULT 0;
    DECLARE v_total_expenses DECIMAL(15,2) DEFAULT 0;
    DECLARE v_final_earnings DECIMAL(15,2) DEFAULT 0;

    -- Error handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        CALL LogError('GetTotalEarnings', 'Unexpected SQL error occurred');
        CALL LogProcedureExecution(
            'GetTotalEarnings',
            p_start_date,
            p_end_date,
            'FAILED',
            'Execution failed due to SQL exception'
        );
    END;

    -- Validate input
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Start date and end date cannot be NULL';
    END IF;

    -- Calculate invoice revenue
    SELECT IFNULL(SUM(net_amount), 0)
    INTO v_total_invoices
    FROM invoices
    WHERE status = 'Paid'
      AND generated_at BETWEEN p_start_date AND p_end_date;

    -- Calculate pharmacy restock expenses
    SELECT IFNULL(SUM(amount), 0)
    INTO v_total_expenses
    FROM hospital_expenses
    WHERE category = 'Pharmacy_Restock'
      AND expense_date BETWEEN p_start_date AND p_end_date;

    -- Final earnings calculation
    SET v_final_earnings = v_total_invoices - v_total_expenses;

    -- Output result
    SELECT 
        v_total_invoices AS total_revenue,
        v_total_expenses AS total_expenses,
        v_final_earnings AS total_earnings;

    -- Log success
    CALL LogProcedureExecution(
        'GetTotalEarnings',
        p_start_date,
        p_end_date,
        'SUCCESS',
        'Total earnings calculated successfully'
    );
END //
DELIMITER ;


 /*****************************************************************************************
 * SECTION 7: DEPARTMENT EARNINGS PROCEDURE
 *****************************************************************************************/
DROP PROCEDURE IF EXISTS GetDepartmentEarnings;
DELIMITER //
CREATE PROCEDURE GetDepartmentEarnings(
    IN p_start_date DATETIME,
    IN p_end_date DATETIME
)
BEGIN
    -- Error handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        CALL LogError('GetDepartmentEarnings', 'SQL error during department earnings calculation');
    END;

    -- Temporary table for aggregation
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_department_earnings (
        department_name VARCHAR(100),
        revenue DECIMAL(15,2)
    );

    TRUNCATE TABLE temp_department_earnings;

    -- Consultation revenue
    INSERT INTO temp_department_earnings
    SELECT 
        d.name,
        SUM(i.net_amount)
    FROM invoices i
    JOIN appointments a ON i.appointment_id = a.appointment_id
    JOIN doctors doc ON a.doctor_id = doc.doctor_id
    JOIN departments d ON doc.dept_id = d.dept_id
    WHERE i.status = 'Paid'
      AND i.generated_at BETWEEN p_start_date AND p_end_date
    GROUP BY d.name;

    -- Lab revenue
    INSERT INTO temp_department_earnings
    SELECT 
        'Laboratory & Diagnostics',
        SUM(i.net_amount)
    FROM invoices i
    WHERE i.test_record_id IS NOT NULL
      AND i.status = 'Paid'
      AND i.generated_at BETWEEN p_start_date AND p_end_date;

    -- Pharmacy revenue
    INSERT INTO temp_department_earnings
    SELECT 
        'Pharmacy',
        SUM(i.net_amount)
    FROM invoices i
    WHERE i.pharmacy_order_id IS NOT NULL
      AND i.status = 'Paid'
      AND i.generated_at BETWEEN p_start_date AND p_end_date;

    -- Final output
    SELECT 
        department_name,
        SUM(revenue) AS total_revenue
    FROM temp_department_earnings
    GROUP BY department_name
    ORDER BY total_revenue DESC;

    -- Cleanup
    DROP TEMPORARY TABLE IF EXISTS temp_department_earnings;

    -- Log execution
    CALL LogProcedureExecution(
        'GetDepartmentEarnings',
        p_start_date,
        p_end_date,
        'SUCCESS',
        'Department earnings generated'
    );
END //
DELIMITER ;


 /*****************************************************************************************
 * SECTION 8: REPORTING VIEWS
 *****************************************************************************************/

-- View: Paid invoices only
CREATE OR REPLACE VIEW vw_paid_invoices AS
SELECT *
FROM invoices
WHERE status = 'Paid';

-- View: Monthly revenue summary
CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT 
    YEAR(generated_at) AS year,
    MONTH(generated_at) AS month,
    SUM(net_amount) AS total_revenue
FROM invoices
WHERE status = 'Paid'
GROUP BY YEAR(generated_at), MONTH(generated_at);


 /*****************************************************************************************
 * SECTION 9: OPTIONAL ANALYTICS PROCEDURE
 *****************************************************************************************/
DROP PROCEDURE IF EXISTS GetYearlyEarnings;
DELIMITER //
CREATE PROCEDURE GetYearlyEarnings(IN p_year INT)
BEGIN
    SELECT 
        p_year AS year,
        SUM(net_amount) AS total_earnings
    FROM invoices
    WHERE status = 'Paid'
      AND YEAR(generated_at) = p_year;
END //
DELIMITER ;


 /*****************************************************************************************
 * END OF SCRIPT
 *****************************************************************************************/

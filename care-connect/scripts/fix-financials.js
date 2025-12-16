const mysql = require('mysql2/promise');
require('dotenv').config({ path: '.env.local' });

async function fixFinancials() {
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: 'careconnect',
        multipleStatements: true,
    });

    console.log('Connected to MySQL...');

    try {
        // 1. Create Table
        console.log('Creating financial_reports table...');
        await connection.query(`
            CREATE TABLE IF NOT EXISTS financial_reports (
                report_id INT AUTO_INCREMENT PRIMARY KEY,
                report_type ENUM('Yearly', 'Monthly', 'Weekly') NOT NULL,
                period_label VARCHAR(50) NOT NULL,
                total_revenue DECIMAL(15, 2) DEFAULT 0.00,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_report (report_type, period_label)
            );
        `);

        // 2. Drop and Recreate Procedure
        console.log('Creating Procedure...');
        await connection.query(`DROP PROCEDURE IF EXISTS RecalculateFinancialReports;`);
        await connection.query(`
            CREATE PROCEDURE RecalculateFinancialReports()
            BEGIN
                -- Clear existing
                TRUNCATE TABLE financial_reports;

                -- A. YEARLY
                INSERT INTO financial_reports (report_type, period_label, total_revenue)
                SELECT 'Yearly', DATE_FORMAT(payment_date, '%Y'), SUM(amount)
                FROM payments
                GROUP BY DATE_FORMAT(payment_date, '%Y');

                -- B. MONTHLY
                INSERT INTO financial_reports (report_type, period_label, total_revenue)
                SELECT 'Monthly', DATE_FORMAT(payment_date, '%Y-%m'), SUM(amount)
                FROM payments
                GROUP BY DATE_FORMAT(payment_date, '%Y-%m');

                -- C. WEEKLY
                INSERT INTO financial_reports (report_type, period_label, total_revenue)
                SELECT 'Weekly', DATE_FORMAT(payment_date, '%x-W%v'), SUM(amount)
                FROM payments
                GROUP BY DATE_FORMAT(payment_date, '%x-W%v');

            END
        `);

        // 3. Populate Data
        console.log('Recalculating Data...');
        await connection.query(`CALL RecalculateFinancialReports();`);

        // 4. Create Triggers (Optional but good for real-time)
        console.log('Creating Triggers...');
        // Drop existing to be safe
        await connection.query(`DROP TRIGGER IF EXISTS trg_update_financials_on_payment;`);
        await connection.query(`
            CREATE TRIGGER trg_update_financials_on_payment
            AFTER INSERT ON payments
            FOR EACH ROW
            BEGIN
                -- Update Yearly
                INSERT INTO financial_reports (report_type, period_label, total_revenue)
                VALUES ('Yearly', DATE_FORMAT(NEW.payment_date, '%Y'), NEW.amount)
                ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.amount;

                -- Update Monthly
                INSERT INTO financial_reports (report_type, period_label, total_revenue)
                VALUES ('Monthly', DATE_FORMAT(NEW.payment_date, '%Y-%m'), NEW.amount)
                ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.amount;

                -- Update Weekly
                INSERT INTO financial_reports (report_type, period_label, total_revenue)
                VALUES ('Weekly', DATE_FORMAT(NEW.payment_date, '%x-W%v'), NEW.amount)
                ON DUPLICATE KEY UPDATE total_revenue = total_revenue + NEW.amount;
            END
        `);

        await connection.query(`DROP TRIGGER IF EXISTS trg_update_financials_on_invoice;`);


        console.log('✅ Financial Reports Table Fixed & Populated.');

        // Check data
        const [rows] = await connection.query('SELECT * FROM financial_reports');
        console.log('Current Report Data:', rows);

    } catch (err) {
        console.error('Error fixing financials:', err);
    } finally {
        await connection.end();
    }
}

fixFinancials();

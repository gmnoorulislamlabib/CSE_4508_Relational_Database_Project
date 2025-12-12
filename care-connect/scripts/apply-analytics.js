const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: '.env.local' });

async function applyAnalytics() {
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: 'careconnect',
        multipleStatements: true,
    });

    console.log('Connected to MySQL...');

    try {
        const sqlFile = fs.readFileSync(path.join(__dirname, '../database/07_analytics.sql'), 'utf8');

        // Split by DELIMITER logic similar to setup
        const blocks = sqlFile
            .replace(/DELIMITER \/\//g, '')
            .replace(/DELIMITER ;/g, '')
            .split('//')
            .map(s => s.trim())
            .filter(s => s.length > 0);

        for (const block of blocks) {
            if (!block) continue;
            try {
                await connection.query(block);
                console.log('Executed block successfully.');
            } catch (e) {
                console.error('Error executing block:', e.message);
            }
        }
        console.log('✅ Financial Analytics Procedures Applied.');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        await connection.end();
    }
}

applyAnalytics();

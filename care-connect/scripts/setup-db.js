const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: '.env.local' });

async function seed() {
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        multipleStatements: true,
    });

    console.log('Connected to MySQL...');

    try {
        // 1. Run Schema (Drops DB and Recreates)
        const schemaSql = fs.readFileSync(path.join(__dirname, '../database/01_schema.sql'), 'utf8');
        await connection.query(schemaSql);
        console.log('✅ Schema created.');

        // 2. Run Procedures/Triggers
        // Note: The driver doesn't support DELIMITER syntax. We need to manually split logic or execute blocks.
        // For simplicity in this script, we will define the procedures directly here to avoid parsing complex SQL files with delimiters.
        // Alternatively, we strip delimiters.

        await connection.query(`USE careconnect;`);

        // We will read the file but we need to remove DELIMITER lines and split by 'END //' or similar if we want to parse.
        // However, it's safer to just hardcode the critical procedures here for the runner script to ensure they work.
        // or just run the file content if we remove DELIMITER keywords and split properly.

        // Let's try reading the file and stripping DELIMITER lines, then splitting by '//'
        const procSqlFile = fs.readFileSync(path.join(__dirname, '../database/02_procedures_triggers.sql'), 'utf8');
        const procBlocks = procSqlFile
            .replace(/DELIMITER \/\//g, '')
            .replace(/DELIMITER ;/g, '')
            .split('//')
            .map(s => s.trim())
            .filter(s => s.length > 0);

        for (const block of procBlocks) {
            if (block.toLowerCase().startsWith('use')) continue; // Skip USE
            try {
                await connection.query(block);
            } catch (e) {
                console.error('Error executing block:', block.substring(0, 50) + '...', e.message);
            }
        }
        console.log('✅ Procedures & Triggers created.');

        // 3. Views
        const viewsSql = fs.readFileSync(path.join(__dirname, '../database/03_views_indexes.sql'), 'utf8');
        await connection.query(viewsSql);
        console.log('✅ Views & Indexes created.');

        // 4. Seed Data
        const seedSql = fs.readFileSync(path.join(__dirname, '../database/04_seed.sql'), 'utf8');
        await connection.query(seedSql);
        console.log('✅ Seed Data inserted.');

        // 5. Advanced Features (Splitting logic needed for DELIMITER)
        console.log('⏳ Applying Advanced Features (Partitioning, Events, Cursors)...');
        const advSqlFile = fs.readFileSync(path.join(__dirname, '../database/06_advanced_features.sql'), 'utf8');
        // Simple split by // for procedures, but the file mixes standard queries and delimiters.
        // We will attempt to run it block by block or use a smarter split.
        // For this specific file, we have standard queries then DELIMITER // block then standard queries.
        // Let's use the same cleaning logic as procedures.
        const advBlocks = advSqlFile
            .replace(/DELIMITER \/\//g, '')
            .replace(/DELIMITER ;/g, '')
            .split('//')
            .map(s => s.trim())
            .filter(s => s.length > 0);

        for (const block of advBlocks) {
            if (!block) continue;
            // Further split by semicolon if it's not a procedure block? 
            // Actually, connection.query with multipleStatements: true can handle standard SQLs separated by ; 
            // BUT mixing them with CREATE PROCEDURE in the same call might be tricky if not parsed right.
            // Let's rely on the fact that our split by // captures the big procedure, 
            // and the other parts are potentially multiple statements.
            try {
                await connection.query(block);
            } catch (e) {
                // Ignore "Table already exists" kind of errors if appropriate, but print others
                console.error('Warning in Advanced Features:', e.message);
            }
        }
        console.log('✅ Advanced Features Applied.');

    } catch (err) {
        console.error('Error seeding database:', err);
    } finally {
        await connection.end();
    }
}

seed();

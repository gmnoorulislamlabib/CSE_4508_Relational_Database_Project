# CareConnect - Advanced Hospital Management System

**CareConnect** is a database-heavy web application designed for the "Team SQL" course project. It features a robust MySQL backend with complex logic and a modern Next.js frontend.

## 🚀 Getting Started

### 1. Database Setup (MySQL)
You must initialize the database before running the application.
1. Make sure you have MySQL installed and running.
2. Navigate to the `database` folder in the project root (or `../database` relative to this app).
3. Execute the SQL scripts in the following order:

```bash
# Example command line execution
mysql -u root -p < ../database/01_schema.sql
mysql -u root -p < ../database/02_procedures_triggers.sql
mysql -u root -p < ../database/03_views_indexes.sql
mysql -u root -p < ../database/04_seed.sql
```

**Files Description:**
- `01_schema.sql`: Creates database, 15 tables, constraints, and JSON columns.
- `02_procedures_triggers.sql`: Adds stored procedures (Booking, Billing), functions, and triggers (Audit, Validation).
- `03_views_indexes.sql`: Creates analytical views and indexes.
- `04_seed.sql`: Populates the database with demo users, doctors, and patients.
- `05_complex_queries.sql`: Contains the 10+ required complex SQL queries for your report.

### 2. Application Setup
1. Copy the environment example:
   ```bash
   cp .env.example .env.local
   ```
2. Update `.env.local` with your MySQL credentials.
3. Install dependencies:
   ```bash
   npm install
   ```
4. Run the development server:
   ```bash
   npm run dev
   ```
5. Open [http://localhost:3000](http://localhost:3000) to view the application.

## 🏗 Project Structure

- `database/`: SQL scripts for schema, logic, and data.
- `app/`: Next.js App Router source code.
- `lib/db.ts`: MySQL connection pool configuration.

## ✨ Features Implemented
- **10+ Complex SQL Queries**: See `database/05_complex_queries.sql`.
- **RBAC**: Admin, Doctor, Patient roles.
- **Audit Logging**: Fully automated via Triggers.
- **Advanced Logic**: Stored Procedures for conflict detection and invoicing.
- **Premium UI**: Modern, responsive interface using Tailwind CSS.

## 🚀 Advanced Database Features (Added)

We have taken the database to the next level with **4 Advanced Features** (`database/06_advanced_features.sql`), specifically targeting course requirements for High Distinction.

### 1. Table Partitioning (Performance)
**Requirement D**: *Advanced feature - Partitioning*
- **Implementation**: Partitioned the `audit_logs` table by Year ranges.
- **Why**: As logs grow to millions of records, partitioning ensures that queries for the current year remain fast, and historical logs can be archived or dropped instantly.

### 2. Scheduled Events (Automation)
**Requirement D**: *Scheduled jobs/events*
- **Implementation**: `evt_auto_cancel_noshows` runs every hour.
- **Logic**: Automatically updates appointments to 'NoShow' if they are still 'Scheduled' 2 hours past their time.
- **Benefit**: Automates administrative cleanup without human intervention.

### 3. Cursor-based Stored Procedures (Complex Logic)
**Requirement C**: *Cursor usage OR bulk operation*
- **Implementation**: `ProcessLoyaltyTiers` procedure.
- **Logic**: 
    - Uses a **CURSOR** to iterate through every patient.
    - Calculates total visits and spending.
    - Assigns a Tier (Gold/Silver/Standard) based on complex rules using `CASE` statements.
    - Upserts data into a summary table `patient_loyalty_program`.

### 4. Full-Text Search (Indexing)
**Requirement B**: *Indexing strategies*
- **Implementation**: Added a `FULLTEXT` index on `medical_records(diagnosis, symptoms)`.
- **Benefit**: Allows efficient natural language searching (e.g., matching "fever" AND "cough") compared to slow `LIKE '%...%'` queries.

---
### 🇧🇩 Localization Update
- **Context**: All seed data (Doctors, Patients, Addresses) is now localized to Bangladesh (Dhaka, Chattogram).
- **Currency**: Dashboard now displays **৳ (BDT)** instead of $.

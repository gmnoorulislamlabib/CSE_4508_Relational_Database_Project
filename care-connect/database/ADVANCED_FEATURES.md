
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

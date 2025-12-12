# Implementation Plan - CareConnect Hospital Management

## Phase 1: Core System Setup (Completed)
- [x] Basic Schema (Users, Doctors, Patients, Appointments)
- [x] Procedures & Triggers 
- [x] Seed Data
- [x] Billing & Financial Reports
- [x] Lab Tests Management & History

## Phase 2: Room Management & Admissions (Current)
### Database Changes
- [ ] Rename `consultation_rooms` to `rooms`.
- [ ] Add `charge_per_day` and expanded `type` ENUM to `rooms`.
- [ ] Create `admissions` table for room bookings (Inpatient).
- [ ] Update FK references in `medical_tests` and `patient_tests`.

### Logic & Procedures
- [ ] Create `BookAdmission` procedure (Check avail, Calc cost, Insert).
- [ ] Create `DischargePatient` procedure.

### UI Implementation
- [ ] "Room Availability" Dashboard Page.
- [ ] Booking Interface for Patients.
up
- [x] Initialize Next.js Application (`care-connect`)
- [ ] Configure Environment Variables (`.env`)
- [ ] Install Database dependencies (`mysql2`, `server-only`)
- [ ] **Schema Design** (10-15 Entities)
    - Users, Profiles, Doctors, Patients, Appointments, MedicalRecords, etc.
- [ ] **SQL Script Generation**
    - `01_schema.sql`: Create tables, relationships, constraints.
    - `02_views_indexes.sql`: Create views and indexes.
    - `03_procedures_functions.sql`: Stored procedures, functions.
    - `04_triggers.sql`: Audit logs, validations.
    - `05_seed.sql`: Dummy data for demonstration.
- [ ] **Execution**: Run scripts against MySQL database.

## 3. Application Development (Frontend + API)
- [ ] **Layout & Navigation**
    - Dynamic sidebar based on User Role (Admin, Doctor, Patient).
    - Landing Page.
- [ ] **Authentication**
    - Login/Register (Custom auth using Users table).
- [ ] **Dashboards**
    - **Admin**: Manage users, view system stats (using SQL Views).
    - **Doctor**: View appointments, manage records.
    - **Patient**: Book appointments, view history.
- [ ] **Core Features**
    - **Appointment Booking**: Transactional workflow (Procedure).
    - **Medical Records**: View/Add (JSON data).
    - **Billing**: Generate Invoice (Procedure/Trigger).

## 4. Documentation & Final Polish
- [ ] Ensure all Requirements are met:
    - 10+ Complex Queries (incorporated in API endpoints/pages).
    - Transaction consistency.
    - Exception handling.
- [ ] Screenshots & Reports.

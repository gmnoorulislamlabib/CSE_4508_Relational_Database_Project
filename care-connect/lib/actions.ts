'use server';

import pool from './db';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { cookies } from 'next/headers';

export async function verifyLogin(formData: FormData) {
    const email = formData.get('email') as string;
    const password = formData.get('password') as string;

    try {
        await pool.query(
            `CALL VerifyAdminCredentials(?, ?, @valid, @uid, @role)`,
            [email, password]
        );
        const [rows] = await pool.query('SELECT @valid as valid, @uid as uid, @role as role');
        const result = (rows as any)[0];

        if (result.valid) {
            // Set session cookie
            (await cookies()).set('session', JSON.stringify({
                uid: result.uid,
                role: result.role
            }), {
                httpOnly: true,
                secure: process.env.NODE_ENV === 'production',
                maxAge: 60 * 60 * 24, // 1 day
                path: '/'
            });

            return { success: true, role: result.role };
        } else {
            return { success: false, error: 'Invalid email or password.' };
        }
    } catch (e: any) {
        return { success: false, error: e.message };
    }
}

// --- Patients ---

export async function addPatient(formData: FormData) {
    const firstName = formData.get('firstName') as string;
    const lastName = formData.get('lastName') as string;
    const email = formData.get('email') as string;
    const phone = formData.get('phone') as string;
    const dob = formData.get('dob') as string;
    const gender = formData.get('gender') as string;
    const address = formData.get('address') as string;
    const bloodGroup = formData.get('bloodGroup') as string;

    const ec_firstName = formData.get('ec_firstName') as string;
    const ec_lastName = formData.get('ec_lastName') as string;
    const ec_dob = formData.get('ec_dob') as string;
    const ec_email = formData.get('ec_email') as string;
    const ec_phone = formData.get('ec_phone') as string;


    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        // 1. Create User
        const [userRes] = await connection.execute(
            `INSERT INTO users (email, password_hash, role) VALUES (?, ?, 'Patient')`,
            [email, 'temp_hash'] // simplified
        );
        const userId = (userRes as any).insertId;

        // 2. Create Profile
        await connection.execute(
            `INSERT INTO profiles (user_id, first_name, last_name, date_of_birth, gender, phone_number, address) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [userId, firstName, lastName, dob, gender, phone, address]
        );

        const medicalHistory = formData.getAll('medicalHistory') as string[];
        const historySummary = medicalHistory.length > 0 ? `Initial History: ${medicalHistory.join(', ')}` : null;

        // 3. Create Patient Record
        await connection.execute(
            `INSERT INTO patients (user_id, blood_group, emergency_contact_first_name, emergency_contact_last_name, emergency_contact_dob, emergency_contact_email, emergency_contact_phone, medical_history_summary) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [userId, bloodGroup, ec_firstName, ec_lastName, ec_dob, ec_email, ec_phone, historySummary]
        );

        await connection.commit();
        revalidatePath('/dashboard/patients');
        return { success: true };
    } catch (error: any) {
        await connection.rollback();
        console.error(error);
        return { success: false, error: error.message };
    } finally {
        connection.release();
    }
}

// --- Doctors ---


export async function getAvailableRooms(roomType: string = 'Consultation') {
    // Calls stored procedure to check "Administrative" + "Occupancy" Availability
    const [rows] = await pool.query(`CALL GetRoomAvailability(?)`, [roomType]);
    return (rows as any)[0];
}
export async function getAllDepartments() {
    const [rows] = await pool.query(`SELECT dept_id, name FROM departments`);
    return rows;
}
export async function getReceptionAvailableRooms() {
    const [rows] = await pool.query(`SELECT room_number, type, charge_per_day FROM View_AvailableRooms`);
    return rows;
}

export async function getRoomAvailabilityStats() {
    const [rows] = await pool.query(`
        SELECT type, COUNT(*) as count 
        FROM rooms 
        WHERE is_available = TRUE 
        AND NOT EXISTS (
            SELECT 1 FROM admissions 
            WHERE admissions.room_number = rooms.room_number 
            AND admissions.status = 'Admitted'
        )
        GROUP BY type
    `);

    // Transform into a map for easier frontend access
    const stats: any = {};
    (rows as any[]).forEach(r => {
        stats[r.type] = r.count;
    });
    return stats;
}


export async function admitPatient(formData: FormData) {
    const patientId = formData.get('patientId');
    const roomType = formData.get('roomType') as string;
    // Payment method logic can be handled after admission success or passed in if procedure supports it
    // For now, the prompt says "book only ...", implies simple booking or with payment. 
    // SP AdmitPatient sets payment_status='Pending'. We might need to process payment separate or update SP.

    // For specific room booking requirements (ICU, AC, Non-AC), we pass roomType.

    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        // 1. Call AdmitPatient Procedure to get a room
        await connection.query(
            `CALL AdmitPatient(?, ?, @roomNumber, @status)`,
            [patientId, roomType]
        );
        const [resRows] = await connection.query('SELECT @roomNumber as roomNumber, @status as status');
        const result = (resRows as any)[0];

        if (result.status !== 'Success') {
            throw new Error(result.status);
        }

        const roomNumber = result.roomNumber;

        // 2. Fetch Charge for Initial Payment (if immediate payment required)
        // If the requirement is "Book by making a payment", we should generate Invoice and Pay.

        const [roomRows] = await connection.query('SELECT charge_per_day FROM rooms WHERE room_number = ?', [roomNumber]);
        const charge = (roomRows as any)[0]?.charge_per_day || 0;

        // Create Invoice for First Day / Deposit
        // We need the admission_id to link invoice? 
        // Our AdmitPatient SP didn't return admission_id, just status. 
        // We can fetch the active admission for this patient.

        const [admRows] = await connection.query(
            `SELECT admission_id FROM admissions WHERE patient_id = ? AND status='Admitted' ORDER BY admission_id DESC LIMIT 1`,
            [patientId]
        );
        const admissionId = (admRows as any)[0].admission_id;

        const [invRes] = await connection.execute(
            `INSERT INTO invoices (total_amount, net_amount, status, generated_at, admission_id) 
                VALUES (?, ?, 'Paid', NOW(), ?)`,
            [charge, charge, admissionId]
        );
        const invoiceId = (invRes as any).insertId;

        // Record Payment
        await connection.execute(
            `INSERT INTO payments (invoice_id, amount, payment_method, payment_date) 
                VALUES (?, ?, 'Online', NOW())`, // Defaulting to Online for self-booking
            [invoiceId, charge]
        );

        // Update Admission Payment Status
        await connection.execute(
            `UPDATE admissions SET payment_status = 'Paid' WHERE admission_id = ?`,
            [admissionId]
        );

        await connection.commit();
        revalidatePath('/dashboard/admissions');
        revalidatePath('/dashboard/admissions');
        revalidatePath('/dashboard/patients');
        revalidatePath('/dashboard/rooms');
        return { success: true, roomNumber };

    } catch (e: any) {
        await connection.rollback();
        return { success: false, error: e.message };
    } finally {
        connection.release();
    }
}

export async function dischargePatient(admissionId: number) {
    try {
        await pool.query('CALL DischargePatient(?)', [admissionId]);
        revalidatePath('/dashboard/admissions');
        return { success: true };
    } catch (e: any) {
        return { success: false, error: e.message };
    }
}
export async function getAvailableTests() {
    const [rows] = await pool.query(`SELECT * FROM medical_tests ORDER BY test_name`);
    return rows;
}
export async function getValidSpecializations(deptId?: string) {
    let query = `SELECT specialization_name, dept_id FROM valid_specializations`;
    const params: any[] = [];

    if (deptId) {
        query += ` WHERE dept_id = ?`;
        params.push(deptId);
    }

    query += ` ORDER BY specialization_name`;
    const [rows] = await pool.query(query, params);
    return rows;
}
export async function getValidConsultationFees() {
    const [rows] = await pool.query(`SELECT amount FROM valid_consultation_fees ORDER BY amount`);
    return rows;
}

export async function getAllPatientsList() {
    const [rows] = await pool.query(`
        SELECT p.patient_id, CONCAT(pr.first_name, ' ', pr.last_name) as name 
        FROM patients p 
        JOIN profiles pr ON p.user_id = pr.user_id
        ORDER BY pr.first_name
    `);
    return rows;
}

export async function getAllDoctorsList() {
    const [rows] = await pool.query(`
        SELECT d.doctor_id, CONCAT(pr.first_name, ' ', pr.last_name) as name, d.specialization
        FROM doctors d 
        JOIN profiles pr ON d.user_id = pr.user_id
        ORDER BY pr.first_name
    `);
    return rows;
}

export async function bookPatientTest(formData: FormData) {
    const patientId = formData.get('patientId');
    const testId = formData.get('testId');
    const doctorId = formData.get('doctorId') || null;
    const processPayment = formData.get('processPayment') === 'on';
    const scheduledDate = formData.get('scheduledDate') || null;

    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        let paymentStatus = 'PENDING';
        let status = 'PENDING_PAYMENT';
        let dateToSave = null;

        if (processPayment) {
            paymentStatus = 'PAID';
            // Trigger will handle status -> 'SCHEDULED' if payment is paid and date is set
            // But we can also set it explicitly if we want, but let's rely on trigger logic or set defaults.
            // Actually trigger says: IF NEW.status = 'PENDING_PAYMENT' AND ... auto update. 
            // So we can insert PENDING_PAYMENT and PAID, and if date is there, it might work?
            // Let's set status to SCHEDULED explicitly if paying and scheduling.
            if (scheduledDate) {
                status = 'SCHEDULED';
                dateToSave = scheduledDate;
            }
        }

        // 1. Create Test Record
        // Trigger trg_set_test_defaults will assign room_number
        // Trigger trg_enforce_test_payment_before_scheduling will check payment if dateToSave is not null
        await connection.execute(
            `INSERT INTO patient_tests (patient_id, test_id, doctor_id, status, payment_status, scheduled_date) 
             VALUES (?, ?, ?, ?, ?, ?)`,
            [patientId, testId, doctorId, status, paymentStatus, dateToSave]
        );

        await connection.commit();
        revalidatePath('/dashboard/tests');
        return { success: true };
    } catch (error: any) {
        await connection.rollback();
        return { success: false, error: error.message };
    } finally {
        connection.release();
    }
}

export async function updateTestResult(recordId: number, resultSummary: string) {
    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        const [rows] = await connection.query(
            `SELECT scheduled_end_time FROM patient_tests WHERE record_id = ?`,
            [recordId]
        );
        const testRecord = (rows as any)[0];

        if (testRecord && testRecord.scheduled_end_time) {
            const endTime = new Date(testRecord.scheduled_end_time);
            const now = new Date();

            // Allow 10 seconds buffer or strictly enforce? 
            // Using strict check as per request ("only after the time duration has passed")
            if (now < endTime) {
                await connection.rollback();
                const diffMs = endTime.getTime() - now.getTime();
                const minutes = Math.floor(diffMs / 60000);
                const seconds = Math.floor((diffMs % 60000) / 1000);
                return { success: false, error: `Test is processing. Time remaining: ${minutes}m ${seconds}s` };
            }
        }

        await connection.execute(
            `UPDATE patient_tests SET status = 'COMPLETED', result_summary = ? WHERE record_id = ?`,
            [resultSummary, recordId]
        );

        await connection.commit();
        revalidatePath('/dashboard/tests');
        revalidatePath('/dashboard/patients'); // To refresh history
        return { success: true };
    } catch (error: any) {
        await connection.rollback();
        return { success: false, error: error.message };
    } finally {
        connection.release();
    }
}

export async function getPendingTests() {
    // AUTO-UPDATE LOGIC:
    // Automatically mark tests as COMPLETED if their scheduled duration has passed.
    try {
        await pool.query(`
            UPDATE patient_tests pt
            JOIN medical_tests t ON pt.test_id = t.test_id
            SET 
                pt.status = 'COMPLETED',
                pt.result_summary = CONCAT('Auto-generated Result for ', t.test_name, ': Analysis completed successfully. Parameters within normal range.')
            WHERE 
                pt.status = 'SCHEDULED' 
                AND pt.scheduled_end_time <= NOW()
        `);
    } catch (e) {
        console.error("Auto-update tests failed:", e);
    }

    const [rows] = await pool.query(`
        SELECT 
            pt.record_id,
            pt.status,
            pt.scheduled_date,
            t.test_name,
            CONCAT(p.first_name, ' ', p.last_name) as patient_name,
            pt.result_summary
        FROM patient_tests pt
        JOIN patients pat ON pt.patient_id = pat.patient_id
        JOIN profiles p ON pat.user_id = p.user_id
        JOIN medical_tests t ON pt.test_id = t.test_id
        ORDER BY pt.scheduled_date DESC, pt.created_at DESC
        LIMIT 50
    `);
    return rows;
}

export async function addDoctor(formData: FormData) {
    const firstName = formData.get('firstName') as string;
    const lastName = formData.get('lastName') as string;
    const email = formData.get('email') as string;
    const phone = formData.get('phone') as string;
    // const dob = formData.get('dob') as string; // Not critical for Doctor Demo
    const gender = formData.get('gender') as string;
    const address = formData.get('address') as string;

    const specialization = formData.get('specialization') as string;
    const deptId = formData.get('deptId') as string;
    const licenseNumber = formData.get('licenseNumber') as string;
    const consultationFee = formData.get('consultationFee') as string;
    const joiningDate = formData.get('joiningDate') as string;
    const roomNumber = formData.get('roomNumber') as string;

    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        // 1. Create User
        const [userRes] = await connection.execute(
            `INSERT INTO users (email, password_hash, role) VALUES (?, ?, 'Doctor')`,
            [email, 'temp_hash']
        );
        const userId = (userRes as any).insertId;

        // 2. Create Profile
        // Using a dummy DOB for doctors for now since it wasn't requested in UI but schema needs it? Schema allows NULL? 
        // Checking schema: date_of_birth is NOT NULL in profiles? actually it doesn't say NOT NULL.
        // Let's assume 1980-01-01 if not provided or add input.
        await connection.execute(
            `INSERT INTO profiles (user_id, first_name, last_name, gender, phone_number, address, date_of_birth) 
             VALUES (?, ?, ?, ?, ?, ?, '1980-01-01')`,
            [userId, firstName, lastName, gender, phone, address]
        );

        // 3. Create Doctor Record (This triggers License Validation)
        const [docRes] = await connection.execute(
            `INSERT INTO doctors (user_id, dept_id, specialization, license_number, consultation_fee, joining_date) 
             VALUES (?, ?, ?, ?, ?, ?)`,
            [userId, deptId, specialization, licenseNumber, consultationFee, joiningDate]
        );
        const doctorId = (docRes as any).insertId;

        // 4. Assign Room (Update Schedule/Room logic or just Room table?)
        // Schema: consultation_rooms has current_doctor_id.
        if (roomNumber) {
            await connection.execute(
                `UPDATE rooms SET is_available = FALSE, current_doctor_id = ? WHERE room_number = ?`,
                [doctorId, roomNumber]
            );
        }

        await connection.commit();
        revalidatePath('/dashboard/doctors');
        return { success: true };
    } catch (error: any) {
        await connection.rollback();
        // MySQL Trigger errors usually come as "Signal .." in message
        return { success: false, error: error.message }; // Will catch "Invalid License ID"
    } finally {
        connection.release();
    }
}

// --- Dashboard Stats ---

export async function getDashboardStats() {
    // Uses the Views and Queries we defined
    // 1. Total Patients
    const [patients] = await pool.query('SELECT COUNT(*) as count FROM patients');

    // 2. Today's Appointments
    const [appointments] = await pool.query(`
        SELECT COUNT(*) as count FROM appointments 
        WHERE DATE(appointment_date) = DATE(NOW())
    `);

    // 3. Pending Invoices (Revenue)
    const [revenue] = await pool.query(`
        SELECT SUM(net_amount) as total FROM invoices WHERE status = 'Unpaid'
    `);

    // 4. Doctors Count
    const [doctors] = await pool.query('SELECT COUNT(*) as count FROM doctors');

    return {
        totalPatients: (patients as any)[0].count,
        todayAppointments: (appointments as any)[0].count,
        pendingRevenue: (revenue as any)[0].total || 0,
        activeDoctors: (doctors as any)[0].count
    };
}

export async function getRecentAppointments(filter?: boolean) {
    let query = `
        SELECT * FROM View_PatientHistory 
    `;

    // If filter is explicitly true (for 'Today' view)
    if (filter) {
        query += ` WHERE DATE(appointment_date) = DATE(NOW()) `;
    }

    query += ` ORDER BY appointment_date DESC LIMIT 50`; // Increased limit for full view use-case

    const [rows] = await pool.query(query);
    return rows;
}

// --- Appointments ---

export async function bookAppointment(formData: FormData) {
    const patientId = formData.get('patientId');
    const doctorId = formData.get('doctorId');
    const date = formData.get('date'); // '2025-01-01T10:00'
    const reason = formData.get('reason');

    try {
        // Call the Stored Procedure
        await pool.query(
            `CALL BookAppointment(?, ?, ?, ?, @status, @invoice_id)`,
            [patientId, doctorId, date, reason]
        );
        const [rows] = await pool.query('SELECT @status as status, @invoice_id as invoice_id');
        const result = (rows as any)[0];

        if (result.status === 'Pending Payment') {
            revalidatePath('/dashboard');
            return { success: true, invoiceId: result.invoice_id };
        } else {
            return { success: false, error: result.status };
        }
    } catch (e: any) {
        return { success: false, error: e.message };
    }
}

export async function checkDoctorAvailability(doctorId: string, date: string) {
    try {
        await pool.query(
            `CALL GetDoctorSlots(?, ?, @slots, @available, @msg)`,
            [doctorId, date]
        );
        const [rows] = await pool.query('SELECT @slots as slots, @available as available, @msg as msg');
        const result = (rows as any)[0];
        return {
            success: true,
            remainingSlots: result.slots,
            isAvailable: result.available === 1,
            message: result.msg
        };
    } catch (e: any) {
        return { success: false, error: e.message };
    }
}



export async function getAvailableTimeSlots(doctorId: string, date: string) {
    // date comes as YYYY-MM-DD
    try {
        const [rows] = await pool.query(
            `CALL GetAvailableTimeSlots(?, ?)`,
            [doctorId, date]
        );
        // Stored procedure returns metadata in first element, result in second usually with mysql2
        // But for CALL returning a result set, it's usually the first array
        return (rows as any)[0] as any[];
    } catch (e) {
        console.error(e);
        return [];
    }
}

export async function getDoctorsWithSchedules() {
    const [rows] = await pool.query(`
        SELECT 
            d.doctor_id, 
            CONCAT(p.first_name, ' ', p.last_name) as name, 
            d.specialization,
            s.day_of_week,
            s.start_time,
            s.end_time
        FROM doctors d
        JOIN profiles p ON d.user_id = p.user_id
        JOIN schedules s ON d.doctor_id = s.doctor_id
        ORDER BY d.doctor_id, s.day_of_week
    `);

    // Group schedules by doctor
    const doctorsMap = new Map();
    (rows as any[]).forEach((row: any) => {
        if (!doctorsMap.has(row.doctor_id)) {
            doctorsMap.set(row.doctor_id, {
                doctor_id: row.doctor_id,
                name: row.name,
                specialization: row.specialization,
                schedules: []
            });
        }
        doctorsMap.get(row.doctor_id).schedules.push({
            day: row.day_of_week,
            start: row.start_time,
            end: row.end_time
        });
    });

    return Array.from(doctorsMap.values());
}

export async function getActiveDoctors() {
    // Queries the View_ActiveDoctors which aggregates room info
    const [rows] = await pool.query(`SELECT * FROM View_ActiveDoctors ORDER BY doctor_name`);
    return rows;
}

export async function getAppointmentReasons(doctorId: string) {
    if (!doctorId) return [];
    const [rows] = await pool.query(`
        SELECT ar.reason_id, ar.reason_text
        FROM appointment_reasons ar
        JOIN doctors d ON ar.dept_id = d.dept_id
        WHERE d.doctor_id = ?
    `, [doctorId]);
    return rows;
}

export async function getPatients() {
    const [rows] = await pool.query(`
        SELECT pat.patient_id, CONCAT(p.first_name, ' ', p.last_name) as name
        FROM patients pat
        JOIN profiles p ON pat.user_id = p.user_id
    `);
    return rows;
}
export async function getCommonMedicalProblems() {
    const [rows] = await pool.query(`SELECT problem_name FROM common_medical_problems ORDER BY category, problem_name`);
    return rows;
}
export async function getFinancialSummary() {
    // Queries the new stored procedure for aggregated financial data
    const [rows] = await pool.query(`CALL GetFinancialSummary()`);
    return (rows as any)[0][0]; // stored procedures return [rows, okPacket], and our result is in rows[0]
}
// --- New Invoice Action ---

export async function generateInvoice(appointmentId: number) {
    try {
        await pool.query('CALL GenerateInvoice(?)', [appointmentId]);
        revalidatePath('/dashboard/billing');
        return { success: true };
    } catch (e: any) {
        return { success: false, error: e.message };
    }
}

export async function processPayment(invoiceId: number, amount: number, method: string) {
    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        await connection.execute(
            `INSERT INTO payments (invoice_id, amount, payment_method) VALUES (?, ?, ?)`,
            [invoiceId, amount, method]
        );

        // Trigger automatically updates Invoice Status to 'Paid' if full amount

        await connection.commit();
        revalidatePath('/dashboard/billing');
        return { success: true };
    } catch (e: any) {
        await connection.rollback();
        return { success: false, error: e.message };
    } finally {
        connection.release();
    }
}

// --- Invoice Details ---

export async function getInvoiceDetails(invoiceId: string) {
    // 1. Fetch Header Info
    const [rows] = await pool.query(`
        SELECT 
            i.invoice_id,
            i.total_amount,
            i.status,
            i.generated_at,
            i.pharmacy_order_id,
            i.appointment_id,
            i.test_record_id,
            CONCAT(p.first_name, ' ', p.last_name) as patient_name,
            p.phone_number,
            p.address,
            u.email
        FROM invoices i
        LEFT JOIN appointments a ON i.appointment_id = a.appointment_id
        LEFT JOIN patient_tests pt ON i.test_record_id = pt.record_id
        LEFT JOIN pharmacy_orders po ON i.pharmacy_order_id = po.order_id
        -- Coalesce patient ID from any source
        LEFT JOIN patients pat ON pat.patient_id = COALESCE(a.patient_id, pt.patient_id, po.patient_id)
        LEFT JOIN profiles p ON pat.user_id = p.user_id
        LEFT JOIN users u ON p.user_id = u.user_id
        WHERE i.invoice_id = ?
    `, [invoiceId]);

    const invoice = (rows as any)[0];
    if (!invoice) return null;

    let items: any[] = [];

    // 2. Fetch Line Items based on Type
    if (invoice.pharmacy_order_id) {
        const [pRows] = await pool.query(`
            SELECT 
                m.name as description, 
                poi.quantity, 
                poi.unit_price as unit_price,
                (poi.quantity * poi.unit_price) as total
            FROM pharmacy_order_items poi
            JOIN medicines m ON poi.medicine_id = m.medicine_id
            WHERE poi.order_id = ?
        `, [invoice.pharmacy_order_id]);
        items = pRows as any[];
    } else if (invoice.test_record_id) {
        const [tRows] = await pool.query(`
            SELECT 
                t.test_name as description, 
                1 as quantity, 
                t.cost as unit_price,
                t.cost as total
            FROM patient_tests pt
            JOIN medical_tests t ON pt.test_id = t.test_id
            WHERE pt.record_id = ?
        `, [invoice.test_record_id]);
        items = tRows as any[];
    } else if (invoice.appointment_id) {
        // Simple Consultation Fee
        const [aRows] = await pool.query(`
            SELECT 
                CONCAT('Consultation - ', d_prof.last_name) as description, 
                1 as quantity, 
                i.total_amount as unit_price,
                i.total_amount as total
            FROM invoices i
            JOIN appointments a ON i.appointment_id = a.appointment_id
            JOIN doctors d ON a.doctor_id = d.doctor_id
            JOIN profiles d_prof ON d.user_id = d_prof.user_id
            WHERE i.invoice_id = ?
        `, [invoiceId]);
        items = aRows as any[];
    }

    return { ...invoice, items };
}

export async function getUnpaidInvoices() {
    // UNION of Appointment/Test Invoices and Pharmacy Invoices
    const [rows] = await pool.query(`
        -- 1. Appointment & Test Invoices (Linked via Appointment)
        SELECT 
            i.invoice_id,
            i.total_amount,
            i.status,
            p.first_name as patient_name,
            d.first_name as doctor_name,
            a.appointment_date
        FROM invoices i
        JOIN appointments a ON i.appointment_id = a.appointment_id
        JOIN patients pat ON a.patient_id = pat.patient_id
        JOIN profiles p ON pat.user_id = p.user_id
        JOIN doctors doc ON a.doctor_id = doc.doctor_id
        JOIN profiles d ON doc.user_id = d.user_id
        WHERE i.status = 'Unpaid'

        UNION ALL

        -- 2. Pharmacy Invoices (Linked via Pharmacy Order)
        SELECT 
            i.invoice_id,
            i.total_amount,
            i.status,
            p.first_name as patient_name,
            'Pharmacy' as doctor_name, -- Placeholder for doctor name column
            po.created_at as appointment_date -- Use order date as date
        FROM invoices i
        JOIN pharmacy_orders po ON i.pharmacy_order_id = po.order_id
        JOIN patients pat ON po.patient_id = pat.patient_id
        JOIN profiles p ON pat.user_id = p.user_id
        WHERE i.status = 'Unpaid'
        
        UNION ALL

        -- 3. Test Only Invoices (If any, linked via Test Record but NO Appointment - rare but possible)
        SELECT 
            i.invoice_id,
            i.total_amount,
            i.status,
            p.first_name as patient_name,
            'Laboratory' as doctor_name,
            pt.scheduled_date as appointment_date
        FROM invoices i
        JOIN patient_tests pt ON i.test_record_id = pt.record_id
        JOIN patients pat ON pt.patient_id = pat.patient_id
        JOIN profiles p ON pat.user_id = p.user_id
        WHERE i.status = 'Unpaid' 
        AND i.appointment_id IS NULL -- Avoid duplicates if test is linked to appt
    `);
    return rows;
}

// --- Pharmacy ---

export async function getMedicines() {
    const [rows] = await pool.query('SELECT * FROM medicines ORDER BY name');
    return rows as any[];
}

export async function restockMedicine(formData: FormData) {
    const medicineId = formData.get('medicineId');
    const quantity = parseInt(formData.get('quantity') as string);
    const unitCost = parseFloat(formData.get('unitCost') as string);
    const totalCost = quantity * unitCost;

    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        // 1. Update Stock
        await connection.execute(
            `UPDATE medicines SET stock_quantity = stock_quantity + ? WHERE medicine_id = ?`,
            [quantity, medicineId]
        );

        // 2. Log Expense
        await connection.execute(
            `INSERT INTO hospital_expenses (category, description, amount, recorded_by) 
             VALUES ('Pharmacy_Restock', CONCAT('Restock Item #', ?), ?, NULL)`,
            [medicineId, totalCost]
        );

        await connection.commit();
        revalidatePath('/dashboard/pharmacy');
        return { success: true };
    } catch (e: any) {
        await connection.rollback();
        return { success: false, error: e.message };
    } finally {
        connection.release();
    }
}

export async function createPharmacySale(patientId: number, items: { medicineId: number, quantity: number, price: number }[]) {
    // 0. Server-side Role Check
    const cookieStore = await cookies();
    const session = cookieStore.get('session');
    if (session) {
        try {
            const role = JSON.parse(session.value).role;
            if (role === 'Admin') {
                return { success: false, error: 'Admins cannot perform sales.' };
            }
        } catch (e) { }
    }

    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        // 1. Calculate Total
        const totalAmount = items.reduce((sum, item) => sum + (item.quantity * item.price), 0);

        // 2. Create Order
        const [orderRes] = await connection.execute(
            `INSERT INTO pharmacy_orders (patient_id, total_amount, status) VALUES (?, ?, 'Pending_Payment')`,
            [patientId, totalAmount]
        );
        const orderId = (orderRes as any).insertId;

        // 3. Create Items
        for (const item of items) {
            // Check stock availability first (UI checks too, but DB safety)
            const [stockRes] = await connection.query('SELECT stock_quantity FROM medicines WHERE medicine_id = ?', [item.medicineId]);
            const currentStock = (stockRes as any)[0]?.stock_quantity || 0;

            if (currentStock < item.quantity) {
                throw new Error(`Insufficient stock for item #${item.medicineId}. Available: ${currentStock}`);
            }

            await connection.execute(
                `INSERT INTO pharmacy_order_items (order_id, medicine_id, quantity, unit_price) VALUES (?, ?, ?, ?)`,
                [orderId, item.medicineId, item.quantity, item.price]
            );
        }

        // 4. Create Invoice (Unpaid)
        const [invRes] = await connection.execute(
            `INSERT INTO invoices (pharmacy_order_id, total_amount, net_amount, status, generated_at) 
             VALUES (?, ?, ?, 'Unpaid', NOW())`,
            [orderId, totalAmount, totalAmount]
        );
        const invoiceId = (invRes as any).insertId;

        await connection.commit();
        revalidatePath('/dashboard/pharmacy');
        revalidatePath('/dashboard/billing');
        return { success: true, invoiceId };
    } catch (e: any) {
        await connection.rollback();
        return { success: false, error: e.message };
    } finally {
        connection.release();
    }
}

export async function getAllAppointments(filter?: 'today' | 'upcoming' | 'all') {
    let query = `SELECT * FROM View_PatientHistory`;
    const params: any[] = [];

    if (filter === 'today') {
        query += ` WHERE DATE(appointment_date) = DATE(NOW())`;
    } else if (filter === 'upcoming') {
        query += ` WHERE appointment_date >= NOW()`;
    }

    query += ` ORDER BY appointment_date DESC`;

    const [rows] = await pool.query(query, params);
    return rows;
}

export async function getAllPatients(query: string = '') {
    const searchTerm = `%${query}%`;
    const [rows] = await pool.query(`
        SELECT 
            p.patient_id,
            prof.first_name,
            prof.last_name,
            prof.phone_number,
            prof.gender,
            TIMESTAMPDIFF(YEAR, prof.date_of_birth, CURDATE()) as age,
            p.blood_group,
            CONCAT(p.emergency_contact_first_name, ' ', p.emergency_contact_last_name) AS emergency_contact_name,
            p.medical_history_summary,
            p.test_history_summary,
            u.email,
            -- Calculate Total Spent
            (SELECT COALESCE(SUM(i.net_amount), 0) 
             FROM invoices i 
             LEFT JOIN appointments a ON i.appointment_id = a.appointment_id
             LEFT JOIN pharmacy_orders po ON i.pharmacy_order_id = po.order_id
             LEFT JOIN patient_tests pt ON i.test_record_id = pt.record_id
             WHERE (a.patient_id = p.patient_id OR po.patient_id = p.patient_id OR pt.patient_id = p.patient_id)
             AND i.status = 'Paid') as total_spent,
             
            -- Aggregate Pharmacy History
            (SELECT GROUP_CONCAT(DISTINCT 
                CONCAT(DATE_FORMAT(po2.created_at, '%Y-%m-%d %h:%i%p'), ': ৳', inv.total_amount)
                ORDER BY po2.created_at DESC SEPARATOR '\n')
             FROM pharmacy_orders po2
             JOIN invoices inv ON po2.order_id = inv.pharmacy_order_id
             WHERE po2.patient_id = p.patient_id AND inv.status = 'Paid') as pharmacy_history_summary

        FROM patients p
        JOIN users u ON p.user_id = u.user_id
        JOIN profiles prof ON u.user_id = prof.user_id
        WHERE 
            prof.first_name LIKE ? OR 
            prof.last_name LIKE ? OR 
            prof.phone_number LIKE ? OR
            u.email LIKE ?
        ORDER BY p.patient_id DESC
    `, [searchTerm, searchTerm, searchTerm, searchTerm]);
    return rows as any[];
}

export async function getRevenueReport(startDate: string, endDate: string) {
    const connection = await pool.getConnection();
    try {
        const startDateTime = `${startDate} 00:00:00`;
        const endDateTime = `${endDate} 23:59:59`;

        const [totalRes] = await connection.query(
            `CALL GetTotalEarnings(?, ?)`,
            [startDateTime, endDateTime]
        );
        const totalEarnings = (totalRes as any)[0][0].total_earnings;

        const [deptRes] = await connection.query(
            `CALL GetDepartmentEarnings(?, ?)`,
            [startDateTime, endDateTime]
        );
        const departmentData = (deptRes as any)[0];

        return {
            totalEarnings,
            departmentData
        };
    } catch (e: any) {
        console.error(e);
        return { totalEarnings: 0, departmentData: [] };
    } finally {
        connection.release();
    }
}

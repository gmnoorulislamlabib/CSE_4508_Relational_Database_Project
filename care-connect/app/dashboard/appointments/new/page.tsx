import { getDoctorsWithSchedules, getPatients, bookAppointment, checkDoctorAvailability, getAppointmentReasons, getAvailableTimeSlots } from '@/lib/actions';
import { BookAppointmentForm } from './form'; // Client component

export default async function NewAppointmentPage() {
    // Fetch data for dropdowns
    let doctors = [];
    let patients = [];

    try {
        doctors = await getDoctorsWithSchedules();
        patients = await getPatients();
    } catch (e) {
        // handle err
    }

    return (
        <div className="max-w-2xl mx-auto">
            <div className="mb-8">
                <h2 className="text-2xl font-bold text-slate-800">Book New Appointment</h2>
                <p className="text-slate-500">Schedule a consultation. Transacts responsibly.</p>
            </div>

            <BookAppointmentForm
                doctors={doctors}
                patients={patients}
                bookAction={bookAppointment}
                checkAvailabilityAction={checkDoctorAvailability}
                getReasonsAction={getAppointmentReasons}
                getSlotsAction={getAvailableTimeSlots}
            />
        </div>
    )
}

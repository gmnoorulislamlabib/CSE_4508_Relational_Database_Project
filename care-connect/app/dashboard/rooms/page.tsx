import { getAllPatientsList, getRoomAvailabilityStats } from '@/lib/actions';
import RoomBookingClient from './RoomBookingClient';
import { cookies } from 'next/headers';

export default async function RoomBookingPage() {
    const cookieStore = await cookies();
    const session = cookieStore.get('session');
    let role = null;
    if (session) {
        try {
            const data = JSON.parse(session.value);
            role = data.role;
        } catch (e) { }
    }

    // In a real app with Auth, we would fetch ONLY the logged in patient if role is patient.
    // For this demo (Admin/Shared View), we pass all patients to allow "Booking For" functionality.

    let patients = [];
    let availabilityStats = {};
    try {
        patients = await getAllPatientsList() as any[];
        availabilityStats = await getRoomAvailabilityStats();
    } catch (e) {
        console.error(e);
    }

    return (
        <div className="animate-fade-in">
            <RoomBookingClient patients={patients} availability={availabilityStats} role={role} />
        </div>
    );
}

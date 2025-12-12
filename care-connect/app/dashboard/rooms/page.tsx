
import { getAllPatientsList, getRoomAvailabilityStats } from '@/lib/actions';
import RoomBookingClient from './RoomBookingClient';

export default async function RoomBookingPage() {

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
            <RoomBookingClient patients={patients} availability={availabilityStats} />
        </div>
    );
}

import { getReceptionAvailableRooms, getAllPatientsList } from '@/lib/actions';
import { Building2, Stethoscope, AlertCircle } from 'lucide-react';
import ReceptionRoomList from './ReceptionClient';

export default async function ReceptionPage() {
    let availableRooms = [];
    let patients = [];
    let error = null;

    try {
        availableRooms = await getReceptionAvailableRooms() as any[];
        // patients = await getAllPatientsList() as any[]; // Not needed for read-only view
    } catch (e: any) {
        error = e.message;
    }

    return (
        <div className="space-y-6 animate-fade-in">
            <div className="flex flex-col gap-2">
                <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-2">
                    <Building2 className="w-6 h-6 text-blue-600" />
                    Reception Desk
                </h1>
                <p className="text-slate-500">
                    Live overview of hospital facilities (Read-Only).
                </p>
            </div>

            {error && (
                <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 flex items-center gap-2">
                    <AlertCircle size={20} />
                    <p>Failed to load data: {error}</p>
                </div>
            )}

            <ReceptionRoomList availableRooms={availableRooms} />
        </div>
    );
}

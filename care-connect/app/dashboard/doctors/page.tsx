import { getActiveDoctors } from '@/lib/actions';
import { Activity, MapPin, Stethoscope, Building2 } from 'lucide-react';
import { cookies } from 'next/headers';

export default async function DoctorsPage() {
    const doctors = await getActiveDoctors() as any[];
    const cookieStore = await cookies();
    const session = cookieStore.get('session');
    let role = null;
    if (session) {
        try {
            const data = JSON.parse(session.value);
            role = data.role;
        } catch (e) { }
    }

    return (
        <div className="space-y-6 animate-fade-in">
            <div className="flex flex-col gap-2">
                <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-2">
                    <Activity className="w-6 h-6 text-emerald-600" />
                    Doctor Directory
                </h1>
                <p className="text-slate-500">
                    Active medical staff with their assigned departments and room numbers.
                </p>
            </div>

            {role === 'Admin' && (
                <div className="flex justify-end">
                    <a href="/dashboard/doctors/new" className="flex items-center gap-2 bg-emerald-600 text-white px-4 py-2 rounded-lg hover:bg-emerald-700 transition-colors shadow-lg shadow-emerald-600/20">
                        <Activity size={18} /> Add New Doctor
                    </a>
                </div>
            )}

            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-sm text-left">
                        <thead className="text-xs text-slate-500 uppercase bg-slate-50 border-b border-slate-100">
                            <tr>
                                <th className="px-6 py-4 font-semibold">Doctor Name</th>
                                <th className="px-6 py-4 font-semibold">Domain / Dept</th>
                                <th className="px-6 py-4 font-semibold">Specialization</th>
                                <th className="px-6 py-4 font-semibold text-right">Room Number</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {doctors.length === 0 ? (
                                <tr>
                                    <td colSpan={4} className="px-6 py-12 text-center text-slate-500">
                                        No active doctors found in the database.
                                    </td>
                                </tr>
                            ) : (
                                doctors.map((doc: any) => (
                                    <tr key={doc.doctor_id} className="hover:bg-slate-50/50 transition-colors group">
                                        <td className="px-6 py-4 font-medium text-slate-900 flex items-center gap-3">
                                            <div className="w-8 h-8 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center font-bold text-xs">
                                                {doc.doctor_name.charAt(0)}
                                            </div>
                                            {doc.doctor_name}
                                        </td>
                                        <td className="px-6 py-4 text-slate-600">
                                            <div className="flex items-center gap-2">
                                                <Building2 className="w-4 h-4 text-slate-400" />
                                                {doc.department_name}
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 text-slate-600">
                                            <div className="flex items-center gap-2">
                                                <Stethoscope className="w-4 h-4 text-slate-400" />
                                                {doc.specialization}
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-slate-100 text-slate-700 font-mono text-xs font-medium border border-slate-200 group-hover:bg-white group-hover:border-emerald-200 group-hover:text-emerald-700 transition-colors">
                                                <MapPin className="w-3 h-3" />
                                                {doc.room_numbers || 'N/A'}
                                            </span>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
                <div className="p-4 bg-slate-50 border-t border-slate-200 text-center text-xs text-slate-400">
                    Data sourced live from 'View_ActiveDoctors'
                </div>
            </div>
        </div>
    );
}

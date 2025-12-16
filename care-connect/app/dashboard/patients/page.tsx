import { getAllPatients } from '@/lib/actions';
import { Plus, Search, User } from 'lucide-react';
import Link from 'next/link';
import { SearchInput } from './search';
import { PatientHistoryButton } from './history-button';
import { cookies } from 'next/headers';

export default async function PatientsPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
    const params = await searchParams;
    const patients = await getAllPatients(params?.q || '');
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
        <div className="space-y-6">
            <div className="flex justify-between items-center">
                <div>
                    <h2 className="text-2xl font-bold text-slate-800">Patients Directory</h2>
                    <p className="text-slate-500">Manage patient records and profiles.</p>
                </div>
                {role !== 'Admin' && (
                    <Link href="/dashboard/patients/new" className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors shadow-lg shadow-blue-600/20">
                        <Plus size={18} /> Add Patient
                    </Link>
                )}
            </div>

            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                {/* Search Bar */}
                <div className="p-4 border-b border-slate-100">
                    <SearchInput />
                </div>

                <div className="overflow-x-auto">
                    <table className="w-full text-sm text-left">
                        <thead className="text-xs text-slate-500 uppercase bg-slate-50 border-b border-slate-100">
                            <tr>
                                <th className="px-6 py-4 font-semibold">Name</th>
                                <th className="px-6 py-4 font-semibold">Contact Info</th>
                                <th className="px-6 py-4 font-semibold">Age/Gender</th>
                                <th className="px-6 py-4 font-semibold">Blood Group</th>
                                <th className="px-6 py-4 font-semibold">Emergency Contact</th>
                                <th className="px-6 py-4 font-semibold text-right">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {patients.length === 0 ? (
                                <tr>
                                    <td colSpan={6} className="px-6 py-8 text-center text-slate-500">No patients registered.</td>
                                </tr>
                            ) : patients.map((p: any) => (
                                <tr key={p.patient_id} className="hover:bg-blue-50/80 transition-all duration-200 group cursor-pointer">
                                    <td className="px-6 py-4">
                                        <div className="flex items-center gap-3">
                                            <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold group-hover:scale-110 transition-transform duration-200">
                                                {p.first_name[0]}{p.last_name[0]}
                                            </div>
                                            <div>
                                                <div className="font-medium text-slate-900 group-hover:text-blue-700 transition-colors">{p.first_name} {p.last_name}</div>
                                                <div className="text-xs text-slate-500">ID: P-{p.patient_id}</div>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="px-6 py-4">
                                        <div className="text-slate-900">{p.phone_number}</div>
                                        <div className="text-xs text-slate-500">{p.email}</div>
                                    </td>
                                    <td className="px-6 py-4 text-slate-600">
                                        {p.age} Yrs / {p.gender}
                                    </td>
                                    <td className="px-6 py-4">
                                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-50 text-red-700 border border-red-100">
                                            {p.blood_group || 'N/A'}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4 text-slate-600">
                                        {p.emergency_contact_name || '-'}
                                    </td>
                                    <td className="px-6 py-4 text-right">
                                        <PatientHistoryButton
                                            history={p.medical_history_summary}
                                            testHistory={p.test_history_summary}
                                            pharmacyHistory={p.pharmacy_history_summary}
                                            totalSpent={Number(p.total_spent)}
                                            patientName={`${p.first_name} ${p.last_name}`}
                                        />
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
}

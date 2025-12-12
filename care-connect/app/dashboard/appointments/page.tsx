import { getAllAppointments, generateInvoice } from '@/lib/actions';
import { BadgeCheck, Clock, XCircle, FileText } from 'lucide-react';

export default async function AppointmentsPage(props: { searchParams: Promise<{ filter?: 'today' | 'upcoming' | 'all' }> }) {
    const searchParams = await props.searchParams;
    const filter = searchParams?.filter;
    const appointments = await getAllAppointments(filter);

    // Debug log to terminal to confirm filter value
    console.log('Appointments Page Filter:', filter);
    console.log('Appointments Count:', (appointments as any).length);

    return (
        <div className="space-y-6">
            <div className="flex justify-between items-center">
                <div>
                    <h2 className="text-2xl font-bold text-slate-800">
                        {filter === 'today' ? "Today's Appointments" : 'All Appointments'}
                    </h2>
                    <p className="text-slate-500">Manage patient visits and generate invoices.</p>
                </div>
                {filter && (
                    <a href="/dashboard/appointments" className="flex items-center gap-2 text-sm text-slate-600 bg-slate-100 hover:bg-slate-200 px-3 py-2 rounded-lg transition-colors">
                        <XCircle size={16} /> Clear Filter
                    </a>
                )}
            </div>

            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                <table className="w-full text-sm text-left">
                    <thead className="text-xs text-slate-500 uppercase bg-slate-50 border-b border-slate-100">
                        <tr>
                            <th className="px-6 py-4 font-semibold">ID</th>
                            <th className="px-6 py-4 font-semibold">Patient</th>
                            <th className="px-6 py-4 font-semibold">Doctor</th>
                            <th className="px-6 py-4 font-semibold">Date</th>
                            <th className="px-6 py-4 font-semibold">Status</th>
                            <th className="px-6 py-4 font-semibold">Invoice</th>
                            <th className="px-6 py-4 font-semibold">Action</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                        {appointments.length === 0 ? (
                            <tr>
                                <td colSpan={7} className="px-6 py-8 text-center text-slate-500">
                                    No appointments found matching this filter.
                                </td>
                            </tr>
                        ) : appointments.map((appt: any) => (
                            <tr key={appt.appointment_id} className="hover:bg-slate-50/50 transition-colors">
                                <td className="px-6 py-4 text-slate-500">#{appt.appointment_id}</td>
                                <td className="px-6 py-4 font-medium text-slate-900">{appt.patient_name}</td>
                                <td className="px-6 py-4 text-slate-600">{appt.doctor_name}</td>
                                <td className="px-6 py-4 text-slate-600">{new Date(appt.appointment_date).toLocaleString()}</td>
                                <td className="px-6 py-4">
                                    {getStatusBadge(appt.status)}
                                </td>
                                <td className="px-6 py-4 text-slate-600">
                                    {appt.total_amount ? `৳${appt.total_amount}` : '-'}
                                </td>
                                <td className="px-6 py-4">
                                    {/* Only allow generating invoice if completed and not yet billed (simplified check) */}
                                    {appt.status === 'Completed' && !appt.total_amount ? (
                                        <form action={async () => {
                                            'use server';
                                            await generateInvoice(appt.appointment_id);
                                        }}>
                                            <button className="flex items-center gap-1 text-xs bg-blue-50 text-blue-600 px-2 py-1 rounded hover:bg-blue-100">
                                                <FileText size={14} /> Generate Bill
                                            </button>
                                        </form>
                                    ) : (
                                        <span className="text-xs text-slate-400">No Action</span>
                                    )}
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

function getStatusBadge(status: string) {
    if (status === 'Confirmed') return <span className="inline-flex items-center gap-1 text-xs font-medium text-green-700 bg-green-50 px-2 py-1 rounded-full"><BadgeCheck size={12} /> Confirmed</span>
    if (status === 'Scheduled') return <span className="inline-flex items-center gap-1 text-xs font-medium text-blue-700 bg-blue-50 px-2 py-1 rounded-full"><Clock size={12} /> Scheduled</span>
    if (status === 'Completed') return <span className="inline-flex items-center gap-1 text-xs font-medium text-slate-700 bg-slate-100 px-2 py-1 rounded-full"><BadgeCheck size={12} /> Completed</span>
    return <span className="inline-flex items-center gap-1 text-xs font-medium text-red-700 bg-red-50 px-2 py-1 rounded-full"><XCircle size={12} /> {status}</span>
}

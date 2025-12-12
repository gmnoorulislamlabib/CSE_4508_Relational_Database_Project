import { getDashboardStats, getRecentAppointments, getActiveDoctors } from '@/lib/actions';
import { Users, Calendar, DollarSign, Activity, Plus } from 'lucide-react';
import Link from 'next/link';

export default async function DashboardPage() {
    // Add try/catch to handle DB connection errors gracefully during first run
    let stats = { totalPatients: 0, todayAppointments: 0, activeDoctors: 0, pendingRevenue: 0 };
    let recentAppointments: any[] = [];
    let activeDoctorsList: any[] = [];
    let error = null;

    try {
        stats = await getDashboardStats();
        recentAppointments = await getRecentAppointments() as any[];
        activeDoctorsList = await getActiveDoctors() as any[];
    } catch (e: any) {
        error = e.message;
    }

    if (error) {
        return (
            <div className="p-6 bg-red-50 border border-red-200 rounded-lg text-red-700">
                <h3 className="font-bold text-lg mb-2">Database Connection Failed</h3>
                <p>Please ensure creating the database and configuring .env.local correctly.</p>
                <pre className="mt-4 bg-white p-4 rounded text-sm overflow-x-auto">{error}</pre>
            </div>
        )
    }

    return (
        <div className="space-y-8 animate-fade-in">
            <div className="flex justify-between items-center">
                <div>
                    <h2 className="text-2xl font-bold text-slate-800">Dashboard Overview</h2>
                    <p className="text-slate-500">Welcome back, here's what's happening today.</p>
                </div>
                <div className="flex gap-3">
                    <Link href="/dashboard/appointments/new" className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors shadow-lg shadow-blue-600/20">
                        <Plus size={18} /> New Appointment
                    </Link>
                    <Link href="/dashboard/patients/new" className="flex items-center gap-2 bg-white text-slate-700 border border-slate-200 px-4 py-2 rounded-lg hover:bg-slate-50 transition-colors">
                        <Users size={18} /> Register Patient
                    </Link>
                </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <Link href="/dashboard/appointments?filter=today" className="block focus:outline-none focus:ring-2 focus:ring-purple-500 rounded-xl">
                    <StatCard title="Today's Appointments" value={stats.todayAppointments} icon={<Calendar className="text-purple-600" />} color="purple" />
                </Link>
                <Link href="/dashboard/billing" className="block focus:outline-none focus:ring-2 focus:ring-orange-500 rounded-xl">
                    <StatCard title="Pending Revenue" value={`৳${stats.pendingRevenue}`} icon={<span className="text-orange-600 font-bold text-xl">৳</span>} color="orange" />
                </Link>
            </div>
        </div>
    );
}

function StatCard({ title, value, icon, color }: any) {
    return (
        <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow relative overflow-hidden group">
            <div className={`absolute top-0 right-0 w-24 h-24 bg-${color}-50 rounded-full -translate-y-1/2 translate-x-1/2 opacity-0 group-hover:opacity-100 transition-opacity`} />
            <div className="flex items-start justify-between mb-4 relative z-10">
                <div>
                    <p className="text-sm font-medium text-slate-500">{title}</p>
                    <h3 className="text-3xl font-bold text-slate-900 mt-1">{value}</h3>
                </div>
                <div className={`p-3 bg-${color}-50 rounded-lg border border-${color}-100`}>
                    {icon}
                </div>
            </div>
        </div>
    );
}

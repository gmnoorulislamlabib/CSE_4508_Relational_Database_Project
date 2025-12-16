import Link from 'next/link';
import { LayoutDashboard, Users, Calendar, FileText, Settings, LogOut, HeartPulse, Building2, Microscope, Bed, Package } from 'lucide-react';
import { cookies } from 'next/headers';

export default async function DashboardLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const cookieStore = await cookies();
    const session = cookieStore.get('session');
    let role = 'Receptionist'; // Default fallback

    if (session) {
        try {
            const data = JSON.parse(session.value);
            role = data.role;
        } catch (e) {
            console.error("Failed to parse session", e);
        }
    }

    const isAdmin = role === 'Admin';

    return (
        <div className="min-h-screen bg-slate-50 flex font-sans text-slate-900">
            {/* Sidebar */}
            <aside className="fixed inset-y-0 left-0 w-64 bg-slate-900 text-white z-50 flex flex-col transition-all">
                <div className="h-16 flex items-center px-6 border-b border-slate-800 gap-3">
                    <HeartPulse className="w-6 h-6 text-blue-500" />
                    <span className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-cyan-400">
                        CareConnect
                    </span>
                </div>

                <div className="flex-1 overflow-y-auto py-6 px-4 space-y-1">
                    <div className="px-2 mb-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">
                        Reception Desk
                    </div>

                    <NavItem href="/dashboard" icon={<LayoutDashboard size={20} />} label="Overview" />
                    {!isAdmin && (
                        <NavItem href="/dashboard/rooms" icon={<Bed size={20} />} label="Book a Room" />
                    )}
                    <NavItem href="/dashboard/reception" icon={<Building2 size={20} />} label="Reception View" />
                    <NavItem href="/dashboard/tests" icon={<Microscope size={20} />} label="Available Tests" />
                    <NavItem href="/dashboard/appointments" icon={<Calendar size={20} />} label="Appointments" />
                    <NavItem href="/dashboard/patients" icon={<Users size={20} />} label="Patients" />
                    <NavItem href="/dashboard/doctors" icon={<HeartPulse size={20} />} label="Doctors Directory" />
                    <NavItem href="/dashboard/billing" icon={<FileText size={20} />} label="Billing & Invoices" />
                    <NavItem href="/dashboard/pharmacy" icon={<Package size={20} />} label="Pharmacy" />

                    {isAdmin && (
                        <>
                            <div className="px-2 mt-8 mb-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">
                                System
                            </div>
                            <NavItem href="/dashboard/reports" icon={<FileText size={20} />} label="Reports (Query View)" />
                            <NavItem href="/dashboard/settings" icon={<Settings size={20} />} label="Settings" />
                        </>
                    )}
                </div>

                <div className="p-4 border-t border-slate-800">
                    <button className="flex items-center gap-3 px-4 py-2 text-sm font-medium text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg w-full transition-colors">
                        <LogOut size={20} />
                        Sign Out
                    </button>
                </div>
            </aside>

            {/* Main Content */}
            <main className="flex-1 ml-64 min-h-screen flex flex-col">
                <header className="h-16 bg-white border-b border-slate-200 sticky top-0 z-40 px-8 flex items-center justify-between shadow-sm">
                    <h1 className="text-xl font-semibold text-slate-800">Hospital Management Portal</h1>
                    <div className="flex items-center gap-4">
                        <div className="text-sm text-right hidden sm:block">
                            <div className="font-medium text-slate-900">{role}</div>
                            <div className="text-slate-500 text-xs">{isAdmin ? 'Full Access' : 'Restricted Access'}</div>
                        </div>
                        <div className={`h-10 w-10 rounded-full flex items-center justify-center font-bold border ${isAdmin ? 'bg-blue-100 text-blue-600 border-blue-200' : 'bg-emerald-100 text-emerald-600 border-emerald-200'}`}>
                            {role.charAt(0)}
                        </div>
                    </div>
                </header>

                <div className="flex-1 p-8">
                    {children}
                </div>
            </main>
        </div>
    );
}

function NavItem({ href, icon, label }: { href: string; icon: React.ReactNode; label: string }) {
    return (
        <Link
            href={href}
            className="flex items-center gap-3 px-4 py-3 text-sm font-medium text-slate-400 rounded-lg hover:bg-blue-600/10 hover:text-blue-400 transition-all group"
        >
            <span className="group-hover:scale-110 transition-transform">{icon}</span>
            {label}
        </Link>
    );
}

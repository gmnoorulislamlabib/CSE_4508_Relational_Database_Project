import { getUnpaidInvoices, processPayment, getFinancialSummary } from '@/lib/actions';
import { CreditCard, Banknote, TrendingUp, Calendar, Clock } from 'lucide-react';
import Link from 'next/link';
import { cookies } from 'next/headers';

export default async function BillingPage({ searchParams }: { searchParams: Promise<{ invoice?: string }> }) {
    const params = await searchParams; // searchParams is a Promise in Next 15+
    const invoices = (await getUnpaidInvoices()) as any[];
    const finStats = await getFinancialSummary();
    const cookieStore = await cookies();
    const session = cookieStore.get('session');
    let role = null;
    if (session) {
        try {
            role = JSON.parse(session.value).role;
        } catch (e) { }
    }

    // Auto-focus logic for "Pay Now" link from Booking
    const highlightInvoiceId = params?.invoice ? parseInt(params.invoice) : null;

    return (
        <div className="space-y-8 animate-fade-in">
            <div className="flex flex-col gap-2">
                <h2 className="text-2xl font-bold text-slate-800">Reception Desk Finance</h2>
                <p className="text-slate-500">Track hospital revenue and manage pending payments.</p>
            </div>

            {/* Transaction Tracker (DB Driven) */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                <StatCard
                    label="Lifetime Revenue"
                    value={`৳${finStats.total_all_time}`}
                    subtext="All Time"
                    icon={<TrendingUp className="text-emerald-500" />}
                    border="border-emerald-200"
                    bg="bg-emerald-50"
                />
                <StatCard
                    label="Yearly Revenue"
                    value={`৳${finStats.total_last_year}`}
                    subtext="Last 365 Days"
                    icon={<Calendar className="text-blue-500" />}
                />
                <StatCard
                    label="Monthly Revenue"
                    value={`৳${finStats.total_last_month}`}
                    subtext="Last 30 Days"
                    icon={<Calendar className="text-purple-500" />}
                />
                <StatCard
                    label="Weekly Revenue"
                    value={`৳${finStats.total_last_week}`}
                    subtext="Last 7 Days"
                    icon={<Clock className="text-orange-500" />}
                />
            </div>

            <div className="border-t border-slate-200 pt-8">
                <h3 className="text-xl font-semibold text-slate-800 mb-6 flex items-center gap-2">
                    <Banknote className="text-slate-400" />
                    Pending Invoices
                </h3>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {invoices.length === 0 ? (
                        <div className="md:col-span-3 text-center py-12 bg-slate-50 rounded-xl border border-dashed border-slate-300">
                            <p className="text-slate-500">No pending invoices found.</p>
                        </div>
                    ) : invoices.map((inv: any) => (
                        <div
                            key={inv.invoice_id}
                            className={`bg-white p-6 rounded-xl border shadow-sm transition-all duration-300
                            ${highlightInvoiceId === inv.invoice_id
                                    ? 'border-blue-500 ring-2 ring-blue-500/20 shadow-lg scale-[1.02]'
                                    : 'border-slate-200 hover:shadow-md'}`}
                        >
                            <div className="flex justify-between items-start mb-4">
                                <div>
                                    <h3 className="font-bold text-lg text-slate-900">{inv.patient_name}</h3>
                                    <p className="text-sm text-slate-500">Invoice #{inv.invoice_id}</p>
                                </div>
                                <span className="bg-orange-100 text-orange-700 text-xs font-bold px-2.5 py-1 rounded-full uppercase tracking-wide">Unpaid</span>
                            </div>

                            <div className="space-y-2 text-sm text-slate-600 mb-6 bg-slate-50 p-3 rounded-lg">
                                <div className="flex justify-between">
                                    <span>Doctor:</span>
                                    <span className="font-medium text-slate-900">{inv.doctor_name}</span>
                                </div>
                                <div className="flex justify-between">
                                    <span>Date:</span>
                                    <span>{new Date(inv.appointment_date).toLocaleDateString()}</span>
                                </div>
                                <div className="pt-2 border-t border-slate-200 flex justify-between text-base font-bold text-slate-900 mt-2">
                                    <span>Total:</span>
                                    <span>৳{inv.total_amount}</span>
                                </div>
                            </div>

                            {role !== 'Admin' && (
                                <div className="flex gap-2">
                                    <Link
                                        href={`/dashboard/billing/${inv.invoice_id}`}
                                        className="flex-1 py-2.5 bg-white border border-slate-200 text-slate-700 font-medium rounded-lg flex items-center justify-center gap-2 hover:bg-slate-50 transition-colors"
                                    >
                                        Details
                                    </Link>
                                    <form action={async () => {
                                        'use server';
                                        await processPayment(inv.invoice_id, inv.total_amount, 'Cash');
                                    }} className="flex-1">
                                        <button className="w-full py-2.5 bg-slate-900 text-white font-medium rounded-lg flex items-center justify-center gap-2 hover:bg-slate-800 transition-colors active:scale-95 duration-150">
                                            <Banknote size={16} /> Pay
                                        </button>
                                    </form>
                                </div>
                            )}
                            {role === 'Admin' && (
                                <Link
                                    href={`/dashboard/billing/${inv.invoice_id}`}
                                    className="w-full py-2.5 bg-white border border-slate-200 text-slate-700 font-medium rounded-lg flex items-center justify-center gap-2 hover:bg-slate-50 transition-colors"
                                >
                                    View Details
                                </Link>
                            )}
                        </div>
                    ))}
                </div>
            </div>
        </div>
    )
}

function StatCard({ label, value, subtext, icon, border = "border-slate-200", bg = "bg-white" }: any) {
    return (
        <div className={`${bg} ${border} border rounded-xl p-5 shadow-sm`}>
            <div className="flex justify-between items-start mb-2">
                <span className="text-sm font-medium text-slate-500">{label}</span>
                {icon}
            </div>
            <div className="text-2xl font-bold text-slate-800">{value}</div>
            <div className="text-xs text-slate-400 mt-1">{subtext}</div>
        </div>
    )
}

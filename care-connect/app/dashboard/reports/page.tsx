import pool from '@/lib/db';
import { Database, Search } from 'lucide-react';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import RevenueReporter from './revenue-reporter';

// ... (REPORTS array remains same, skipped for brevity in tool call if not strictly needed in context but I'll leave it as is if I can't reach it)
// wait, replaced content replaces the block. I need to be careful with imports.
// Let's replace the top of the file to include imports, and then the start of the function.

// Actually, I can just replace the component function start and add imports at top.
// Since existing imports are lines 1-2.

const REPORTS = [
    {
        id: 1,
        title: "High Value Doctors",
        description: "Doctors charging above average consultation fee (Nested Subquery)",
        sql: `SELECT 
    CONCAT(d_prof.first_name, ' ', d_prof.last_name) AS doctor_name, 
    d.consultation_fee
FROM doctors d
JOIN profiles d_prof ON d.user_id = d_prof.user_id
WHERE d.consultation_fee > (SELECT AVG(consultation_fee) FROM doctors)`
    },
    {
        id: 2,
        title: "Revenue by Department",
        description: "Rollup aggregation of revenue by department and doctor",
        sql: `SELECT 
    dept.name AS department,
    CONCAT(p.first_name, ' ', p.last_name) AS doctor_name,
    SUM(i.net_amount) AS total_revenue
FROM invoices i
JOIN appointments a ON i.appointment_id = a.appointment_id
JOIN doctors d ON a.doctor_id = d.doctor_id
JOIN departments dept ON d.dept_id = dept.dept_id
JOIN profiles p ON d.user_id = p.user_id
WHERE i.status = 'Paid'
GROUP BY dept.name, p.user_id WITH ROLLUP`
    },
    {
        id: 3,
        title: "Patient Spending Rank",
        description: "Ranking patients by total spend (Window Function)",
        sql: `SELECT 
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    SUM(i.net_amount) AS total_spent,
    RANK() OVER (ORDER BY SUM(i.net_amount) DESC) AS spending_rank
FROM patients pat
JOIN profiles p ON pat.user_id = p.user_id
JOIN appointments a ON pat.patient_id = a.patient_id
JOIN invoices i ON a.appointment_id = i.appointment_id
WHERE i.status = 'Paid'
GROUP BY pat.patient_id, p.first_name, p.last_name`
    },
    {
        id: 4,
        title: "Financial Performance (View)",
        description: "Yearly, Monthly, and Weekly Revenue (Pre-calculated View)",
        sql: `SELECT * FROM financial_reports`
    }
];

export default async function ReportsPage({ searchParams }: { searchParams: { q?: string } }) {
    const cookieStore = await cookies();
    const session = cookieStore.get('session');
    let role = null;
    if (session) {
        try {
            const data = JSON.parse(session.value);
            role = data.role;
        } catch (e) { }
    }

    if (role !== 'Admin') {
        redirect('/dashboard');
    }

    const activeReport = REPORTS.find(r => r.id.toString() === searchParams?.q);
    let results: any[] = [];
    let error = null;

    if (activeReport) {
        try {
            const [rows] = await pool.query(activeReport.sql);
            results = rows as any[];
        } catch (e: any) {
            error = e.message;
        }
    }

    return (
        <div className="space-y-6">
            <div className="mb-8">
                <h2 className="text-2xl font-bold text-slate-800">Advanced Reports</h2>
                <p className="text-slate-500">Run complex analysis on your hospital data.</p>
            </div>

            <RevenueReporter />

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="space-y-4">
                    <h3 className="font-semibold text-slate-700 uppercase text-xs tracking-wider">Available Reports</h3>
                    {REPORTS.map(r => (
                        <a
                            key={r.id}
                            href={`/dashboard/reports?q=${r.id}`}
                            className={`block p-4 rounded-xl border transition-all 
                         ${activeReport?.id === r.id ? 'bg-blue-50 border-blue-200 ring-1 ring-blue-500' : 'bg-white border-slate-200 hover:border-blue-300'}`}
                        >
                            <div className="flex items-start justify-between mb-2">
                                <Database size={18} className={activeReport?.id === r.id ? 'text-blue-600' : 'text-slate-400'} />
                            </div>
                            <h4 className="font-semibold text-slate-900 text-sm mb-1">{r.title}</h4>
                            <p className="text-xs text-slate-500">{r.description}</p>
                        </a>
                    ))}
                </div>

                <div className="md:col-span-2 space-y-4">
                    <h3 className="font-semibold text-slate-700 uppercase text-xs tracking-wider">Results View</h3>
                    <div className="bg-white min-h-[400px] rounded-xl border border-slate-200 shadow-sm p-6 overflow-x-auto">
                        {!activeReport ? (
                            <div className="h-full flex flex-col items-center justify-center text-slate-400">
                                <Search size={48} className="mb-4 opacity-20" />
                                <p>Select a report to generate data.</p>
                            </div>
                        ) : error ? (
                            <div className="text-red-600 bg-red-50 p-4 rounded-lg">
                                <p className="font-bold">Error executing query:</p>
                                <pre className="text-xs mt-2 whitespace-pre-wrap">{error}</pre>
                            </div>
                        ) : (
                            <div className="space-y-4">
                                <div className="flex items-center justify-between">
                                    <h3 className="font-bold text-lg">{activeReport.title}</h3>
                                    <span className="text-xs bg-slate-100 text-slate-600 px-2 py-1 rounded font-mono">{results.length} rows</span>
                                </div>
                                <table className="w-full text-sm text-left border-collapse">
                                    <thead className="bg-slate-50 text-slate-500 uppercase text-xs">
                                        <tr>
                                            {results.length > 0 && Object.keys(results[0]).map(key => (
                                                <th key={key} className="px-4 py-3 border-b border-slate-200 font-semibold">{key.replace(/_/g, ' ')}</th>
                                            ))}
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {results.map((row, i) => (
                                            <tr key={i} className="hover:bg-slate-50/50">
                                                {Object.values(row).map((val: any, j) => (
                                                    <td key={j} className="px-4 py-3 border-b border-slate-100 text-slate-700">
                                                        {val === null ? <span className="text-slate-300 italic">NULL</span> : String(val)}
                                                    </td>
                                                ))}
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

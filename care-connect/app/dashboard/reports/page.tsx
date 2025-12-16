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
        description: "Rollup aggregation of revenue by department (Grand Total included)",
        sql: `SELECT 
    COALESCE(department, 'GRAND TOTAL') AS department,
    SUM(revenue) AS total_revenue
FROM (
    SELECT 
        dept.name AS department,
        i.net_amount AS revenue
    FROM invoices i
    JOIN appointments a ON i.appointment_id = a.appointment_id
    JOIN doctors d ON a.doctor_id = d.doctor_id
    JOIN departments dept ON d.dept_id = dept.dept_id
    WHERE i.status = 'Paid'

    UNION ALL
    
    SELECT 
        'Laboratory' AS department,
        i.net_amount AS revenue
    FROM invoices i
    WHERE i.test_record_id IS NOT NULL 
    AND i.status = 'Paid'

    UNION ALL

    SELECT 
        'Pharmacy Sales' AS department,
        i.net_amount AS revenue
    FROM invoices i
    WHERE i.pharmacy_order_id IS NOT NULL
    AND i.status = 'Paid'

    UNION ALL

    SELECT
        'Pharmacy (Restock Expenses)' AS department,
        -(amount) AS revenue
    FROM hospital_expenses
    WHERE category = 'Pharmacy_Restock'

) AS combined_revenue
GROUP BY department WITH ROLLUP`
    },
    {
        id: 3,
        title: "Patient Spending Rank",
        description: "Ranking patients by total spend across all services (Window Function)",
        sql: `SELECT 
    CONCAT(prof.first_name, ' ', prof.last_name) AS patient_name,
    SUM(i.net_amount) AS total_spent,
    RANK() OVER (ORDER BY SUM(i.net_amount) DESC) AS spending_rank
FROM invoices i
LEFT JOIN appointments a ON i.appointment_id = a.appointment_id
LEFT JOIN patient_tests pt ON i.test_record_id = pt.record_id
LEFT JOIN pharmacy_orders po ON i.pharmacy_order_id = po.order_id
JOIN patients pat ON pat.patient_id = COALESCE(a.patient_id, pt.patient_id, po.patient_id)
JOIN profiles prof ON pat.user_id = prof.user_id
WHERE i.status = 'Paid'
GROUP BY pat.patient_id, prof.first_name, prof.last_name`
    },
    {
        id: 4,
        title: "Financial Performance (View)",
        description: "Yearly, Monthly, and Weekly Revenue (Pre-calculated table)",
        sql: `SELECT 
    report_type AS Report_Type,
    period_label AS Period,
    CONCAT('৳', FORMAT(total_revenue, 2)) AS Revenue,
    DATE_FORMAT(last_updated, '%M %d, %Y %h:%i %p') AS Last_Updated
FROM financial_reports
ORDER BY 
    FIELD(report_type, 'Yearly', 'Monthly', 'Weekly'), 
    period_label DESC`
    }
];

export default async function ReportsPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
    const params = await searchParams;
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

    const activeReport = REPORTS.find(r => r.id.toString() === params.q);
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

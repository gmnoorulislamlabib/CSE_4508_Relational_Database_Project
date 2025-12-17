'use client';

import { useState } from 'react';
import { getRevenueReport } from '@/lib/actions';
import { Calendar, DollarSign, TrendingUp, Filter } from 'lucide-react';

export default function RevenueReporter() {
    const [startDate, setStartDate] = useState('');
    const [endDate, setEndDate] = useState('');
    const [loading, setLoading] = useState(false);
    const [report, setReport] = useState<any>(null);

    async function handleGenerate() {
        if (!startDate || !endDate) return;
        setLoading(true);
        try {
            const data = await getRevenueReport(startDate, endDate);
            setReport(data);
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6 mb-8 transform transition-all hover:shadow-md">
            <div className="flex items-center gap-3 mb-6 border-b border-slate-100 pb-4">
                <div className="p-2 bg-green-100 text-green-600 rounded-lg">
                    <TrendingUp size={24} />
                </div>
                <div>
                    <h3 className="text-lg font-bold text-slate-900">Financial Analytics</h3>
                    <p className="text-sm text-slate-500">Analyze earnings by date range and department</p>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                <div>
                    <label className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-1 block">Start Date</label>
                    <div className="relative">
                        <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-4 h-4" />
                        <input
                            type="date"
                            className="w-full pl-10 pr-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-green-500 outline-none text-sm font-medium"
                            value={startDate}
                            onChange={(e) => setStartDate(e.target.value)}
                        />
                    </div>
                </div>
                <div>
                    <label className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-1 block">End Date</label>
                    <div className="relative">
                        <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-4 h-4" />
                        <input
                            type="date"
                            className="w-full pl-10 pr-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-green-500 outline-none text-sm font-medium"
                            value={endDate}
                            onChange={(e) => setEndDate(e.target.value)}
                        />
                    </div>
                </div>
                <div className="flex items-end">
                    <button
                        onClick={handleGenerate}
                        disabled={loading || !startDate || !endDate}
                        className="w-full py-2 bg-slate-900 text-white rounded-lg font-medium hover:bg-slate-800 disabled:opacity-50 flex items-center justify-center gap-2 transition-colors"
                    >
                        {loading ? 'Analyzing...' : (
                            <>
                                <Filter size={16} /> Generate Report
                            </>
                        )}
                    </button>
                </div>
            </div>

            {report && (
                <div className="animate-fade-in space-y-6">
                    {/* Total Earning Card */}
                    <div className="bg-gradient-to-br from-green-50 to-emerald-50 border border-green-100 p-6 rounded-xl flex items-center justify-between">
                        <div>
                            <p className="text-green-800 font-medium mb-1">Total Period Earnings</p>
                            <h4 className="text-3xl font-bold text-green-900 flex items-center gap-1">
                                <span className="text-lg">৳</span>
                                {Number(report.totalEarnings).toLocaleString()}
                            </h4>
                        </div>
                        <div className="h-12 w-12 bg-green-200 rounded-full flex items-center justify-center text-green-700">
                            <span className="text-2xl font-bold">৳</span>
                        </div>
                    </div>

                    {/* Department Breakdown */}
                    <div>
                        <h4 className="font-semibold text-slate-800 mb-4">Department Breakdown</h4>
                        <div className="overflow-hidden rounded-xl border border-slate-200">
                            <table className="w-full text-sm text-left">
                                <thead className="bg-slate-50 text-slate-500 font-semibold border-b border-slate-200">
                                    <tr>
                                        <th className="px-5 py-3">Department / Source</th>
                                        <th className="px-5 py-3 text-right">Revenue</th>
                                        <th className="px-5 py-3 text-right">Share</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-slate-100">
                                    {report.departmentData.length > 0 ? report.departmentData.map((dept: any, i: number) => {
                                        const share = report.totalEarnings > 0
                                            ? Math.round((Number(dept.total_revenue) / report.totalEarnings) * 100)
                                            : 0;

                                        return (
                                            <tr key={i} className="hover:bg-slate-50/50">
                                                <td className="px-5 py-3 font-medium text-slate-700">{dept.department_name}</td>
                                                <td className="px-5 py-3 text-right font-mono text-slate-600">৳{Number(dept.total_revenue).toLocaleString()}</td>
                                                <td className="px-5 py-3 text-right">
                                                    <span className="inline-block px-2 py-1 rounded bg-slate-100 text-xs font-bold text-slate-600">
                                                        {share}%
                                                    </span>
                                                </td>
                                            </tr>
                                        );
                                    }) : (
                                        <tr>
                                            <td colSpan={3} className="px-5 py-8 text-center text-slate-400 italic">
                                                No revenue recorded for this period.
                                            </td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

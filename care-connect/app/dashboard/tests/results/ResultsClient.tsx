
'use client';

import { useState } from 'react';
import { updateTestResult } from '@/lib/actions';
import { ClipboardList, CheckCircle, Search } from 'lucide-react';

export function ResultsClient({ orders }: { orders: any[] }) {
    const [selectedOrder, setSelectedOrder] = useState<any>(null);
    const [resultText, setResultText] = useState('');
    const [isSaving, setIsSaving] = useState(false);

    async function handleSave() {
        if (!selectedOrder || !resultText) return;
        setIsSaving(true);
        const res = await updateTestResult(selectedOrder.record_id, resultText);
        setIsSaving(false);

        if (res.success) {
            setSelectedOrder(null);
            setResultText('');
        } else {
            alert(res.error || "Failed to update result.");
        }
    }

    return (
        <div className="space-y-6 animate-fade-in">
            <div className="flex flex-col gap-2">
                <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-2">
                    <ClipboardList className="w-6 h-6 text-blue-600" />
                    Lab Management
                </h1>
                <p className="text-slate-500">
                    Update results for scheduled tests.
                </p>
            </div>

            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-sm text-left">
                        <thead className="bg-slate-50 text-xs uppercase text-slate-500 border-b border-slate-100">
                            <tr>
                                <th className="px-6 py-4">ID</th>
                                <th className="px-6 py-4">Patient</th>
                                <th className="px-6 py-4">Test</th>
                                <th className="px-6 py-4">Status</th>
                                <th className="px-6 py-4">Result</th>
                                <th className="px-6 py-4">Action</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {orders.length === 0 ? (
                                <tr>
                                    <td colSpan={6} className="px-6 py-8 text-center text-slate-500">No recent orders found.</td>
                                </tr>
                            ) : orders.map((order) => (
                                <tr key={order.record_id} className="hover:bg-slate-50">
                                    <td className="px-6 py-4 font-mono text-xs">#{order.record_id}</td>
                                    <td className="px-6 py-4 font-medium text-slate-900">{order.patient_name}</td>
                                    <td className="px-6 py-4 text-slate-700">{order.test_name}</td>
                                    <td className="px-6 py-4">
                                        <span className={`px-2 py-1 rounded-full text-xs font-medium 
                                            ${order.status === 'COMPLETED' ? 'bg-green-100 text-green-700' :
                                                order.status === 'SCHEDULED' ? 'bg-blue-100 text-blue-700' : 'bg-orange-100 text-orange-700'}`}>
                                            {order.status}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4 text-slate-500 max-w-xs truncate">
                                        {order.result_summary || '-'}
                                    </td>
                                    <td className="px-6 py-4">
                                        {order.status === 'COMPLETED' ? (
                                            <button
                                                onClick={() => { setSelectedOrder(order); setResultText(''); }}
                                                className="text-blue-600 hover:underline font-medium"
                                            >
                                                Update Result
                                            </button>
                                        ) : (
                                            <span className="text-slate-400 italic text-xs flex items-center gap-1">
                                                <div className="w-2 h-2 bg-blue-400 rounded-full animate-pulse"></div>
                                                Processing...
                                            </span>
                                        )}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Edit Modal */}
            {selectedOrder && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm p-4">
                    <div className="bg-white rounded-xl w-full max-w-lg shadow-2xl p-6">
                        <h3 className="text-xl font-bold text-slate-900 mb-4">Finalize Test Result</h3>
                        <p className="text-sm text-slate-500 mb-4">
                            Rank: {selectedOrder.test_name} for <strong>{selectedOrder.patient_name}</strong>
                        </p>

                        <div className="mb-4">
                            <label className="block text-sm font-medium text-slate-700 mb-2">Select Result Outcome</label>
                            <div className="relative">
                                <select
                                    value={resultText}
                                    onChange={(e) => setResultText(e.target.value)}
                                    className="w-full px-4 py-3 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none appearance-none bg-white text-slate-700"
                                >
                                    <option value="" disabled>-- Choose a standardised result --</option>
                                    <option value="Normal - Within Reference Range">Normal - Within Reference Range</option>
                                    <option value="Abnormal - OUT of Reference Range">Abnormal - OUT of Reference Range</option>
                                    <option value="Positive / Detected">Positive / Detected</option>
                                    <option value="Negative / Not Detected">Negative / Not Detected</option>
                                    <option value="Critical High">Critical High - Immediate Attention</option>
                                    <option value="Critical Low">Critical Low - Immediate Attention</option>
                                    <option value="Inconclusive - Retest Recommended">Inconclusive - Retest Recommended</option>
                                </select>
                                <div className="absolute inset-y-0 right-0 flex items-center px-4 pointer-events-none text-slate-500">
                                    <svg className="w-4 h-4 fill-current" viewBox="0 0 20 20"><path d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" /></svg>
                                </div>
                            </div>
                            <p className="text-xs text-slate-400 mt-2">
                                Please select the most appropriate outcome based on the lab analysis.
                            </p>
                        </div>

                        <div className="flex gap-3 justify-end">
                            <button
                                onClick={() => setSelectedOrder(null)}
                                className="px-4 py-2 text-slate-600 hover:bg-slate-100 rounded-lg"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={handleSave}
                                disabled={!resultText || isSaving}
                                className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
                            >
                                {isSaving ? 'Saving...' : 'Save & Complete'}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

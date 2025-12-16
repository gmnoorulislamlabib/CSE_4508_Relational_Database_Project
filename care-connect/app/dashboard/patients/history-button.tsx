'use client';

import { useState } from 'react';
import { FileClock, X, Receipt, Pill } from 'lucide-react';

export function PatientHistoryButton({
    history,
    testHistory,
    pharmacyHistory,
    totalSpent,
    patientName
}: {
    history: string | null,
    testHistory?: string | null,
    pharmacyHistory?: string | null,
    totalSpent?: number,
    patientName: string
}) {
    const [isOpen, setIsOpen] = useState(false);

    return (
        <>
            <button
                onClick={() => setIsOpen(true)}
                className="text-blue-600 hover:text-blue-800 font-medium text-xs flex items-center gap-1 ml-auto"
            >
                <FileClock size={14} /> View History
            </button>

            {isOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm animate-fade-in p-4">
                    <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl flex flex-col max-h-[80vh]">
                        <div className="flex justify-between items-start p-6 border-b border-slate-100 bg-slate-50/50 rounded-t-2xl">
                            <div>
                                <h3 className="text-xl font-bold text-slate-900">Medical History</h3>
                                <p className="text-sm text-slate-500 mb-2">for {patientName}</p>
                                <div className="inline-flex items-center gap-2 px-3 py-1 bg-emerald-100 text-emerald-800 rounded-full text-xs font-bold shadow-sm">
                                    <Receipt size={12} />
                                    Total Spent: ৳{totalSpent || 0}
                                </div>
                            </div>
                            <button onClick={() => setIsOpen(false)} className="text-slate-400 hover:text-slate-600 transition-colors bg-white hover:bg-slate-100 p-2 rounded-full">
                                <X size={20} />
                            </button>
                        </div>

                        <div className="p-6 overflow-y-auto space-y-8 custom-scrollbar">
                            {/* Medical History Section */}
                            <div>
                                <h4 className="font-bold text-slate-800 mb-3 flex items-center gap-2 uppercase text-xs tracking-wider">
                                    <FileClock size={16} className="text-blue-500" /> Medical Summary
                                </h4>
                                {history ? (
                                    <div className="bg-slate-50 p-4 rounded-xl border border-slate-200">
                                        <pre className="whitespace-pre-wrap font-sans text-sm text-slate-700 leading-relaxed">
                                            {history}
                                        </pre>
                                    </div>
                                ) : (
                                    <p className="text-sm text-slate-400 italic pl-1">No medical history recorded.</p>
                                )}
                            </div>

                            {/* Test History Section */}
                            <div>
                                <h4 className="font-bold text-slate-800 mb-3 flex items-center gap-2 uppercase text-xs tracking-wider">
                                    <span className="text-purple-500 text-lg">🧪</span> Lab Test History
                                </h4>
                                {testHistory ? (
                                    <div className="bg-purple-50 p-4 rounded-xl border border-purple-100">
                                        <pre className="whitespace-pre-wrap font-sans text-sm text-slate-700 leading-relaxed">
                                            {testHistory}
                                        </pre>
                                    </div>
                                ) : (
                                    <p className="text-sm text-slate-400 italic pl-1">No lab tests recorded.</p>
                                )}
                            </div>

                            {/* Pharmacy Purchase History */}
                            <div>
                                <h4 className="font-bold text-slate-800 mb-3 flex items-center gap-2 uppercase text-xs tracking-wider">
                                    <Pill size={16} className="text-emerald-500" /> Pharmacy Purchases
                                </h4>
                                {pharmacyHistory ? (
                                    <div className="bg-emerald-50 p-4 rounded-xl border border-emerald-100 max-h-40 overflow-y-auto">
                                        <div className="space-y-2">
                                            {pharmacyHistory.split('\n').map((line, i) => (
                                                <div key={i} className="text-sm text-slate-700 flex justify-between border-b border-emerald-100 pb-1 last:border-0">
                                                    <span>{line.split(': ')[0]}</span>
                                                    <span className="font-semibold">{line.split(': ')[1]}</span>
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                ) : (
                                    <p className="text-sm text-slate-400 italic pl-1">No pharmacy purchases recorded.</p>
                                )}
                            </div>
                        </div>

                        <div className="p-4 border-t border-slate-100 bg-slate-50 rounded-b-2xl flex justify-end">
                            <button
                                onClick={() => setIsOpen(false)}
                                className="px-6 py-2 bg-slate-900 text-white rounded-lg font-medium hover:bg-slate-800 transition-colors shadow-lg shadow-slate-900/10"
                            >
                                Close
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </>
    );
}

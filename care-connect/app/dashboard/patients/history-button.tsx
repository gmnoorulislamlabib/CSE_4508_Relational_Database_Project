'use client';

import { useState } from 'react';
import { FileClock, X } from 'lucide-react';

export function PatientHistoryButton({ history, testHistory, patientName }: { history: string | null, testHistory?: string | null, patientName: string }) {
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
                        <div className="flex justify-between items-center p-6 border-b border-slate-100">
                            <div>
                                <h3 className="text-xl font-bold text-slate-900">Medical History</h3>
                                <p className="text-sm text-slate-500">for {patientName}</p>
                            </div>
                            <button onClick={() => setIsOpen(false)} className="text-slate-400 hover:text-slate-600 transition-colors">
                                <X size={24} />
                            </button>
                        </div>

                        <div className="p-6 overflow-y-auto space-y-6">
                            {/* Medical History Section */}
                            <div>
                                <h4 className="font-semibold text-slate-800 mb-2 flex items-center gap-2">
                                    <FileClock size={16} /> Medical History
                                </h4>
                                {history ? (
                                    <div className="bg-slate-50 p-4 rounded-lg border border-slate-200">
                                        <pre className="whitespace-pre-wrap font-sans text-sm text-slate-700 leading-relaxed">
                                            {history}
                                        </pre>
                                    </div>
                                ) : (
                                    <p className="text-sm text-slate-400 italic">No medical history recorded.</p>
                                )}
                            </div>

                            {/* Test History Section */}
                            <div>
                                <h4 className="font-semibold text-slate-800 mb-2 flex items-center gap-2">
                                    <span className="text-blue-600">🧪</span> Lab Test History
                                </h4>
                                {testHistory ? (
                                    <div className="bg-blue-50 p-4 rounded-lg border border-blue-100">
                                        <pre className="whitespace-pre-wrap font-sans text-sm text-slate-700 leading-relaxed">
                                            {testHistory}
                                        </pre>
                                    </div>
                                ) : (
                                    <p className="text-sm text-slate-400 italic">No lab tests recorded.</p>
                                )}
                            </div>
                        </div>

                        <div className="p-6 border-t border-slate-100 bg-slate-50 rounded-b-2xl">
                            <button
                                onClick={() => setIsOpen(false)}
                                className="w-full py-2.5 bg-slate-900 text-white rounded-xl font-medium hover:bg-slate-800 transition-colors"
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

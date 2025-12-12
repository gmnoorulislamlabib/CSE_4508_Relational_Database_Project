'use client';

import { useState } from 'react';
import { Microscope, Clock, TestTube, CheckCircle, AlertCircle, X, Calendar as CalendarIcon, User, Stethoscope, ClipboardList } from 'lucide-react';
import { bookPatientTest } from '@/lib/actions';
import { useFormStatus } from 'react-dom';

export default function TestsClient({ tests, patients, doctors }: { tests: any[], patients: any[], doctors: any[] }) {
    const [selectedTest, setSelectedTest] = useState<any>(null);
    const [bookingSuccess, setBookingSuccess] = useState(false);
    const [error, setError] = useState('');

    return (
        <div className="space-y-6 animate-fade-in">
            <div className="flex flex-col gap-2">
                <div className="flex justify-between items-start">
                    <div>
                        <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-2">
                            <Microscope className="w-6 h-6 text-purple-600" />
                            Medical Tests Catalog
                        </h1>
                        <p className="text-slate-500">
                            Select a test to book for a registered patient.
                        </p>
                    </div>
                    <a href="/dashboard/tests/results" className="px-4 py-2 bg-white border border-slate-200 text-slate-700 rounded-lg hover:bg-slate-50 text-sm font-medium flex items-center gap-2">
                        <ClipboardList size={16} /> Manage Orders
                    </a>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {tests.map((test: any) => (
                    <div key={test.test_id} className="bg-white rounded-xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow p-6 flex flex-col justify-between h-full group">
                        <div>
                            <div className="flex justify-between items-start mb-4">
                                <div className="p-3 bg-purple-50 rounded-lg text-purple-600 group-hover:bg-purple-100 transition-colors">
                                    <TestTube size={24} />
                                </div>
                                <span className="font-bold text-lg text-slate-900 flex items-center gap-0.5">
                                    <span className="text-sm font-normal text-slate-500 mr-1">BDT</span>
                                    {test.cost}
                                </span>
                            </div>
                            <h3 className="text-lg font-bold text-slate-800 mb-2">{test.test_name}</h3>
                            <p className="text-slate-600 text-sm mb-4 line-clamp-3">
                                {test.description}
                            </p>
                        </div>
                        <div className="space-y-4">
                            <div className="pt-4 border-t border-slate-100 flex items-center gap-2 text-sm text-slate-500">
                                <Clock size={16} />
                                <span>Duration: ~{test.estimated_duration_minutes} mins</span>
                            </div>

                            <button
                                onClick={() => setSelectedTest(test)}
                                className="w-full py-2.5 bg-slate-900 text-white rounded-lg font-medium hover:bg-slate-800 transition-colors flex items-center justify-center gap-2"
                            >
                                Book Test
                            </button>
                        </div>
                    </div>
                ))}
            </div>

            {/* Booking Modal */}
            {selectedTest && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm animate-fade-in p-4">
                    <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden max-h-[90vh] overflow-y-auto">
                        <div className="bg-slate-50 px-6 py-4 border-b border-slate-100 flex justify-between items-center">
                            <h3 className="font-bold text-lg text-slate-800">Book {selectedTest.test_name}</h3>
                            <button onClick={() => { setSelectedTest(null); setError(''); }} className="text-slate-400 hover:text-slate-600">
                                <X size={20} />
                            </button>
                        </div>

                        <div className="p-6">
                            {bookingSuccess ? (
                                <div className="flex flex-col items-center text-center py-8">
                                    <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mb-4">
                                        <CheckCircle className="w-8 h-8 text-green-600" />
                                    </div>
                                    <h3 className="text-xl font-bold text-slate-900 mb-2">Test Booked Successfully!</h3>
                                    <p className="text-slate-600 mb-6">The patient has been registered for the test.</p>
                                    <button
                                        onClick={() => { setBookingSuccess(false); setSelectedTest(null); }}
                                        className="px-6 py-2 bg-slate-900 text-white rounded-lg"
                                    >
                                        Close
                                    </button>
                                </div>
                            ) : (
                                <BookingForm
                                    test={selectedTest}
                                    patients={patients}
                                    doctors={doctors}
                                    onSuccess={() => setBookingSuccess(true)}
                                    onError={setError}
                                />
                            )}

                            {error && (
                                <div className="mt-4 p-3 bg-red-50 text-red-700 rounded-lg text-sm flex items-center gap-2">
                                    <AlertCircle size={16} /> {error}
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

function BookingForm({ test, patients, doctors, onSuccess, onError }: any) {
    const [payNow, setPayNow] = useState(false);

    async function handleSubmit(formData: FormData) {
        const res = await bookPatientTest(formData);
        if (res.success) {
            onSuccess();
        } else {
            onError(res.error || 'Failed to book test');
        }
    }

    return (
        <form action={handleSubmit} className="space-y-4">
            <input type="hidden" name="testId" value={test.test_id} />

            <div className="space-y-2">
                <label className="text-sm font-medium text-slate-700 flex items-center gap-2">
                    <User size={16} /> Patient
                </label>
                <select name="patientId" required className="w-full px-4 py-2 border border-slate-200 rounded-lg bg-white">
                    <option value="">Select Patient...</option>
                    {patients.map((p: any) => (
                        <option key={p.patient_id} value={p.patient_id}>{p.name} (ID: {p.patient_id})</option>
                    ))}
                </select>
            </div>

            <div className="space-y-2">
                <label className="text-sm font-medium text-slate-700 flex items-center gap-2">
                    <Stethoscope size={16} /> Referring Doctor (Optional)
                </label>
                <select name="doctorId" className="w-full px-4 py-2 border border-slate-200 rounded-lg bg-white">
                    <option value="">None / Self-Referred</option>
                    {doctors.map((d: any) => (
                        <option key={d.doctor_id} value={d.doctor_id}>{d.name} ({d.specialization})</option>
                    ))}
                </select>
            </div>

            <div className="pt-2 border-t border-slate-100">
                <label className="flex items-center gap-3 p-3 border border-slate-200 rounded-lg cursor-pointer hover:bg-slate-50">
                    <div className="flex items-center h-5">
                        <input
                            name="processPayment"
                            type="checkbox"
                            className="w-4 h-4 text-blue-600 rounded border-slate-300 focus:ring-blue-500"
                            checked={payNow}
                            onChange={(e) => setPayNow(e.target.checked)}
                        />
                    </div>
                    <div className="flex-1">
                        <p className="font-medium text-slate-900">Process Payment Now</p>
                        <p className="text-xs text-slate-500">Uncheck to pay later (Pending status)</p>
                    </div>
                    <span className="font-bold text-slate-900">৳{test.cost}</span>
                </label>
            </div>

            <div className={`space-y-2 transition-opacity ${payNow ? 'opacity-100' : 'opacity-50 pointer-events-none'}`}>
                <label className="text-sm font-medium text-slate-700 flex items-center gap-2">
                    <CalendarIcon size={16} /> Schedule Date & Time
                </label>
                <input
                    name="scheduledDate"
                    type="datetime-local"
                    required={payNow}
                    disabled={!payNow}
                    className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                />
                {!payNow && <p className="text-xs text-orange-600">Payment required to schedule time.</p>}
            </div>

            <div className="pt-2">
                <SubmitButton label={payNow ? `Pay ৳${test.cost} & Book` : 'Book Order (Pay Later)'} />
            </div>
        </form>
    );
}

function SubmitButton({ label }: { label: string }) {
    const { pending } = useFormStatus();
    return (
        <button
            type="submit"
            disabled={pending}
            className="w-full py-3 bg-blue-600 text-white rounded-xl font-medium hover:bg-blue-700 disabled:opacity-50 flex items-center justify-center gap-2"
        >
            {pending ? 'Processing...' : label}
        </button>
    );
}

'use client';

import { useFormStatus } from 'react-dom';
import { useState } from 'react';
import { Loader2, CheckCircle2, AlertCircle } from 'lucide-react';
import Link from 'next/link';

export function BookAppointmentForm({ doctors, patients, bookAction, checkAvailabilityAction, getReasonsAction, getSlotsAction }: any) {
    const [selectedDoctor, setSelectedDoctor] = useState<any>(null);
    const [modalOpen, setModalOpen] = useState(false);
    const [successMessage, setSuccessMessage] = useState('');
    const [error, setError] = useState<string | null>(null);
    const [bookingDetails, setBookingDetails] = useState<any>(null);
    const [reasons, setReasons] = useState<any[]>([]);

    async function handleDoctorChange(e: any) {
        const docId = parseInt(e.target.value);
        const doctor = doctors.find((d: any) => d.doctor_id === docId);
        setSelectedDoctor(doctor || null);

        // Reset reasons
        setReasons([]);

        if (doctor && getReasonsAction) {
            const fetchedReasons = await getReasonsAction(docId);
            setReasons(fetchedReasons as any[]);
        }
    }

    async function handleSubmit(formData: FormData) {
        setError(null);

        // Manually construct the date field expected by the server action
        const datePart = formData.get('date_only') as string;
        const timePart = formData.get('time_only') as string;

        if (!datePart || !timePart) {
            setError('Please select both a date and a time slot.');
            return;
        }

        // Combine to ISO-like format specific for our DB input (YYYY-MM-DD HH:MM)
        // or just append to formData (FormData is immutable directly, need to set)
        formData.set('date', `${datePart}T${timePart}`);

        // Final database-side check before confirming
        if (bookAction && checkAvailabilityAction) {
            const docId = formData.get('doctorId') as string;
            const fullDate = formData.get('date') as string;

            // Check availability one last time (this calls DB Stored Procedure)
            const check = await checkAvailabilityAction(docId, fullDate);

            if (!check.success || !check.isAvailable) {
                setError(check.message || 'Selected slot is not available.');
                return;
            }

            // Proceed to book
            const res = await bookAction(formData);
            if (res.success) {
                // Update remaining slots for display
                setBookingDetails((prev: any) => ({
                    ...prev,
                    remainingSlots: check.remainingSlots - 1,
                    invoiceId: res.invoiceId // Store the Invoice ID
                }));
                setSuccessMessage('Appointment booked successfully!');
                setModalOpen(true);
            } else {
                setError(res.error);
            }
        }
    }

    function formatTime12Hour(timeStr: string) {
        if (!timeStr) return '';
        const [hours, minutes] = timeStr.split(':');
        let h = parseInt(hours);
        const ampm = h >= 12 ? 'PM' : 'AM';
        h = h % 12;
        h = h ? h : 12; // the hour '0' should be '12'
        return `${h}:${minutes} ${ampm}`;
    }

    function getNextDate(dayName: string) {
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const targetDayIndex = days.indexOf(dayName);
        if (targetDayIndex === -1) return dayName; // Fallback

        const today = new Date();
        const currentDayIndex = today.getDay();

        let daysUntilTarget = targetDayIndex - currentDayIndex;
        if (daysUntilTarget <= 0) {
            daysUntilTarget += 7; // Get next week's occurrence if today or passed
        }

        const nextDate = new Date(today);
        nextDate.setDate(today.getDate() + daysUntilTarget);

        // Format: Sun, Dec 14
        return nextDate.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
    }

    return (
        <>
            <form action={handleSubmit} className="bg-white rounded-xl border border-slate-200 shadow-sm p-8 space-y-6">

                {error && (
                    <div className="p-4 bg-red-50 text-red-600 rounded-lg flex items-center gap-2 text-sm">
                        <AlertCircle size={16} />
                        {error}
                    </div>
                )}

                <div className="space-y-2">
                    <label className="text-sm font-medium text-slate-700">Patient</label>
                    <select name="patientId" required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all">
                        <option value="">Select Patient...</option>
                        {patients.map((p: any) => (
                            <option key={p.patient_id} value={p.patient_id}>{p.name}</option>
                        ))}
                    </select>
                </div>

                <div className="space-y-2">
                    <label className="text-sm font-medium text-slate-700">Doctor</label>
                    <select
                        name="doctorId"
                        required
                        className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all"
                        onChange={handleDoctorChange}
                    >
                        <option value="">Select Doctor...</option>
                        {doctors.map((d: any) => (
                            <option key={d.doctor_id} value={d.doctor_id}>{d.name} — {d.specialization}</option>
                        ))}
                    </select>
                </div>

                {selectedDoctor && (
                    <div className="bg-blue-50 border border-blue-100 rounded-lg p-4 text-sm text-blue-800">
                        <p className="font-semibold mb-2">Available Schedules (Next 7 Days):</p>
                        <ul className="list-disc list-inside space-y-1">
                            {selectedDoctor.schedules && selectedDoctor.schedules.length > 0 ? (
                                selectedDoctor.schedules.map((s: any, idx: number) => (
                                    <li key={idx}>
                                        <span className="font-semibold">{getNextDate(s.day)}:</span> {formatTime12Hour(s.start)} - {formatTime12Hour(s.end)}
                                        <span className="ml-2 text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full">5 Slots / Day</span>
                                    </li>
                                ))
                            ) : (
                                <li>No schedules found.</li>
                            )}
                        </ul>
                    </div>
                )}

                <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                        <label className="text-sm font-medium text-slate-700">Date</label>
                        <input
                            name="date_only"
                            type="date"
                            min={new Date().toISOString().slice(0, 10)}
                            required
                            className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all"
                            onChange={async (e) => {
                                const date = e.target.value;
                                if (selectedDoctor && date) {
                                    setBookingDetails((prev: any) => ({ ...prev, date: date }));
                                    // Fetch slots from DB
                                    if (getSlotsAction) {
                                        const slots = await getSlotsAction(selectedDoctor.doctor_id, date);
                                        setBookingDetails((prev: any) => ({ ...prev, availableTimeSlots: slots }));
                                    }
                                }
                            }}
                        />
                    </div>

                    <div className="space-y-2">
                        <label className="text-sm font-medium text-slate-700">Available Time</label>
                        <select
                            name="time_only"
                            required
                            className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all"
                            disabled={!bookingDetails?.availableTimeSlots}
                        >
                            <option value="">Select Time...</option>
                            {bookingDetails?.availableTimeSlots?.map((slot: any) => (
                                <option key={slot.slot_time} value={slot.slot_time}>{slot.formatted_time}</option>
                            ))}
                        </select>
                    </div>
                </div>

                {/* Hidden input to combine date and time for the server action */}
                <input type="hidden" name="date" value={bookingDetails?.date ? `${bookingDetails.date}T${(document.querySelector('select[name="time_only"]') as HTMLSelectElement)?.value || '00:00'}` : ''} />
                {/* We need a small JS trick or state to update the hidden input because formData pulls from the DOM. 
                    Actually, better to compose it in handleSubmit or use a state for time.
                */}

                {/* RE-IMPLEMENTATION: Use state for time to insure hidden input is correct */}
                <input type="hidden" name="dummy_trigger" />
                {/* 
                   Wait, formData.get('date') is expected by bookAction. 
                   We will construct it in handleSubmit instead of a hidden input to avoid sync issues.
                */}

                <div className="space-y-2">
                    <label className="text-sm font-medium text-slate-700">Reason for Visit</label>
                    <select name="reason" required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all">
                        <option value="">Select Reason...</option>
                        {reasons.length > 0 ? (
                            reasons.map((r: any) => (
                                <option key={r.reason_id} value={r.reason_text}>{r.reason_text}</option>
                            ))
                        ) : (
                            <option value="" disabled>Select a doctor first to see valid reasons</option>
                        )}
                        <option value="Other">Other (Special Case)</option>
                    </select>
                </div>

                <div className="pt-4 flex justify-end gap-3">
                    <button type="button" onClick={() => window.history.back()} className="px-6 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-200 rounded-lg hover:bg-slate-50">Cancel</button>
                    <SubmitButton />
                </div>
            </form>

            {/* Success Modal */}
            {modalOpen && (
                <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 animate-in fade-in duration-200">
                    <div className="bg-white rounded-xl shadow-2xl p-8 max-w-sm w-full mx-4 transform transition-all scale-100">
                        <div className="flex flex-col items-center text-center space-y-4">
                            <div className="w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mb-2">
                                <CheckCircle2 className="w-8 h-8 text-yellow-600" />
                            </div>
                            <h3 className="text-xl font-bold text-slate-900">Booking Initialized</h3>
                            <p className="text-slate-600 text-sm">
                                Your appointment is <strong>Pending Payment</strong>. Please complete the payment to confirm your slot.
                            </p>

                            <div className="flex flex-col gap-3 w-full pt-2">
                                {/* Use window.location.href or Link to navigate to the specific invoice if possible. 
                                    Since we don't have a specific /billing/[id] page yet, we link to general billing. 
                                    Ideally, we pass the invoice ID.
                                 */}
                                <Link href={bookingDetails?.invoiceId ? `/dashboard/billing?invoice=${bookingDetails.invoiceId}` : "/dashboard/billing"} className="w-full bg-blue-600 text-white py-2.5 rounded-lg hover:bg-blue-700 font-medium transition-colors shadow-lg shadow-blue-200">
                                    Pay Now
                                </Link>
                                <Link href="/dashboard" className="w-full bg-white text-slate-600 py-2.5 rounded-lg border border-slate-200 hover:bg-slate-50 font-medium transition-colors">
                                    Pay Later
                                </Link>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </>
    )
}

function SubmitButton() {
    const { pending } = useFormStatus()

    return (
        <button type="submit" disabled={pending} className="px-6 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50 flex items-center gap-2">
            {pending && <Loader2 className="animate-spin w-4 h-4" />}
            Confirm Booking
        </button>
    )
}


'use client';

import { useState } from 'react';
import { admitPatient } from '@/lib/actions';
import { Building2, X, AlertCircle, CheckCircle, Bed, Activity, User, CreditCard, Stethoscope, Microscope, Search } from 'lucide-react';
import { useFormStatus } from 'react-dom';

/*
  Since the prompt requirements specifically mentioned:
  "A registered patient should be able to book only the following rooms: ICU,AC-room and Non-Ac room..
   They should be able to book consultation rooms, lab rooms"
   
  We will interpret this as a booking interface for patients (or reception on behalf of them).
  The original "Room Availability" was for reception to see everything.
  The prompt now focuses on "A registered patient should be able to ...".
  So we should create a user-friendly booking wizard that allows selecting these types.

  However, for this "Room Availability" dashboard page, we will keep the Reception view but emphasize the booking flow
  as per the requirement.

  We will display categories:
  1. Inpatient Care (ICU, AC, Non-AC)
  2. Outpatient & Services (Consultation, Lab)
*/

export default function RoomBookingClient({ patients, availability, role }: { patients: any[], availability: any, role?: string }) {
    const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
    const [searchTerm, setSearchTerm] = useState('');

    // Admin is read-only
    const canBook = role !== 'Admin';

    const categories = [
        {
            id: 'inpatient',
            title: 'Room Booking',
            description: canBook ? 'Book rooms for admitted patients.' : 'View hospital room availability (Read Only).',
            icon: <Bed className="w-8 h-8 text-blue-600" />,
            types: [
                { id: 'ICU', label: 'ICU (Intensive Care)', charge: '৳10,000', icon: <Activity className="text-red-500" /> },
                { id: 'Operation_Theater', label: 'Operation Theater', charge: '৳15,000', icon: <Activity className="text-orange-500" /> },
                { id: 'Ward_AC', label: 'AC Cabin/Ward', charge: '৳3,000', icon: <Building2 className="text-blue-500" /> },
                { id: 'Ward_NonAC', label: 'Non-AC Ward', charge: '৳1,500', icon: <Building2 className="text-slate-500" /> },
            ]
        }
    ];

    return (
        <div className="space-y-8 max-w-5xl mx-auto">

            {/* Header / Intro */}
            <div className="bg-gradient-to-r from-blue-600 to-cyan-600 rounded-2xl p-8 text-white shadow-lg">
                <h2 className="text-3xl font-bold mb-2">Hospital Room Booking</h2>
                <p className="text-blue-100 max-w-xl">
                    {canBook
                        ? "Select a category below to check availability and book rooms for registered patients."
                        : "Administrator View: Monitoring current room occupancy and availability."}
                </p>
            </div>

            {/* Category Selection */}
            <div className="grid md:grid-cols-2 gap-6">
                {categories.map((cat) => (
                    <div key={cat.id} className="bg-white rounded-xl border border-slate-200 shadow-sm p-6 hover:shadow-md transition-all">
                        <div className="flex items-center gap-4 mb-4">
                            <div className="p-3 bg-slate-50 rounded-lg">
                                {cat.icon}
                            </div>
                            <div>
                                <h3 className="text-xl font-bold text-slate-800">{cat.title}</h3>
                                <p className="text-sm text-slate-500">{cat.description}</p>
                            </div>
                        </div>

                        <div className="space-y-3">
                            {cat.types.map((type) => {
                                const count = availability[type.id] || 0;
                                const isAvailable = count > 0;

                                return (
                                    <button
                                        key={type.id}
                                        onClick={() => canBook && isAvailable && setSelectedCategory(type.id)}
                                        disabled={!isAvailable || !canBook}
                                        className={`w-full flex items-center justify-between p-4 rounded-lg border transition-all group group text-left
                                            ${isAvailable && canBook
                                                ? 'border-slate-100 hover:border-blue-500 hover:bg-blue-50 cursor-pointer'
                                                : 'border-slate-100 bg-slate-50 opacity-80 cursor-default'}`}
                                    >
                                        <div className="flex items-center gap-3">
                                            <div className={isAvailable ? '' : 'grayscale'}>{type.icon}</div>
                                            <span className={`font-medium ${isAvailable && canBook ? 'text-slate-700 group-hover:text-blue-700' : 'text-slate-500'}`}>
                                                {type.label}
                                            </span>
                                        </div>
                                        <div className="flex items-center gap-3">
                                            {isAvailable ? (
                                                <>
                                                    <span className="text-xs font-semibold bg-green-100 text-green-700 px-2 py-1 rounded">
                                                        {count} Available
                                                    </span>
                                                    {canBook && (
                                                        <span className="text-blue-600 opacity-0 group-hover:opacity-100 transition-opacity text-sm font-bold">
                                                            Book &rarr;
                                                        </span>
                                                    )}
                                                </>
                                            ) : (
                                                <span className="text-xs font-semibold bg-red-100 text-red-600 px-2 py-1 rounded">
                                                    Fully Booked
                                                </span>
                                            )}
                                        </div>
                                    </button>
                                );
                            })}
                        </div>
                    </div>
                ))}
            </div>

            {selectedCategory && (
                <BookingModal
                    roomType={selectedCategory}
                    patients={patients}
                    onClose={() => setSelectedCategory(null)}
                />
            )}
        </div>
    );
}

function BookingModal({ roomType, patients, onClose }: any) {
    const [bookingResult, setBookingResult] = useState<any>(null);
    const [error, setError] = useState('');

    const labels: any = {
        'ICU': 'Intensive Care Unit',
        'Ward_AC': 'AC Ward/Cabin',
        'Ward_NonAC': 'Non-AC Ward',
        'Consultation': 'Consultation Room',
        'Lab': 'Laboratory Room'
    };

    async function handleSubmit(formData: FormData) {
        const res = await admitPatient(formData);
        if (res.success) {
            setBookingResult({ success: true, roomNumber: res.roomNumber });
        } else {
            setError(res.error || 'Failed to book room.');
        }
    }

    if (bookingResult?.success) {
        return (
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm p-4 animate-fade-in">
                <div className="bg-white rounded-2xl w-full max-w-sm shadow-2xl p-6 text-center">
                    <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                        <CheckCircle className="w-8 h-8 text-green-600" />
                    </div>
                    <h3 className="text-xl font-bold text-slate-900 mb-2">Booking Confirmed!</h3>
                    <p className="text-slate-600 mb-6">
                        Room <strong>{bookingResult.roomNumber}</strong> has been successfully booked.
                    </p>
                    <button onClick={onClose} className="w-full py-2 bg-slate-900 text-white rounded-lg hover:bg-slate-800">
                        Done
                    </button>
                </div>
            </div>
        )
    }

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm p-4 animate-fade-in">
            <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl overflow-hidden">
                <div className="bg-slate-900 px-6 py-4 flex justify-between items-center">
                    <div>
                        <h3 className="font-bold text-lg text-white">Book {labels[roomType]}</h3>
                        <p className="text-blue-200 text-xs">Category: {roomType}</p>
                    </div>
                    <button onClick={onClose} className="text-white/70 hover:text-white">
                        <X size={20} />
                    </button>
                </div>

                <div className="p-6">
                    <form action={handleSubmit} className="space-y-4">
                        <input type="hidden" name="roomType" value={roomType} />

                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700 flex items-center gap-2">
                                <User size={16} /> Select Patient
                            </label>
                            <select name="patientId" required className="w-full px-4 py-2 border border-slate-200 rounded-lg bg-white focus:ring-2 focus:ring-blue-500">
                                <option value="">Choose a registered patient...</option>
                                {patients.map((p: any) => (
                                    <option key={p.patient_id} value={p.patient_id}>{p.name} (ID: {p.patient_id})</option>
                                ))}
                            </select>
                            <p className="text-xs text-slate-500">
                                Only registered patients can book rooms.
                            </p>
                        </div>

                        {/* Payment Info varies by type, but sticking to Prompt Requirement 'Make a payment' */}
                        <div className="p-4 bg-slate-50 rounded-lg border border-slate-200 space-y-3">
                            <div className="flex justify-between text-base font-bold text-slate-900">
                                <span>Booking Payment</span>
                                <span>
                                    {roomType === 'ICU' ? '৳10,000' :
                                        roomType === 'Ward_AC' ? '৳3,000' :
                                            roomType === 'Ward_NonAC' ? '৳1,500' : 'Starts from ৳0/Variable'}
                                </span>
                            </div>
                            <p className="text-xs text-slate-500">
                                {roomType === 'Consultation' || roomType === 'Lab' ?
                                    'Consultation and Lab rooms are typically assigned via Appointments/Tests, but can be manually booked here if needed for specific procedures.' :
                                    'Required as initial deposit for admission.'}
                            </p>
                        </div>

                        {error && (
                            <div className="p-3 bg-red-50 text-red-700 rounded-lg text-sm flex items-center gap-2">
                                <AlertCircle size={16} /> {error}
                            </div>
                        )}

                        <SubmitButton />
                    </form>
                </div>
            </div>
        </div>
    );
}

function SubmitButton() {
    const { pending } = useFormStatus();
    return (
        <button
            type="submit"
            disabled={pending}
            className="w-full py-3 bg-blue-600 text-white rounded-xl font-medium hover:bg-blue-700 disabled:opacity-50 flex items-center justify-center gap-2 mt-4"
        >
            <CreditCard size={18} />
            {pending ? 'Processing...' : 'Confirm Booking & Pay'}
        </button>
    );
}

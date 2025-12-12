'use client';

import { addDoctor, getAvailableRooms, getAllDepartments, getValidSpecializations, getValidConsultationFees } from '@/lib/actions';
import { useState, useEffect } from 'react';
import { useFormStatus } from 'react-dom';
import { Loader2, CheckCircle, AlertCircle, Stethoscope, Building2 } from 'lucide-react';
import { useRouter } from 'next/navigation';

export default function NewDoctorForm() {
    const router = useRouter();
    const [showModal, setShowModal] = useState(false);
    const [error, setError] = useState('');
    const [rooms, setRooms] = useState<any[]>([]);
    const [departments, setDepartments] = useState<any[]>([]);
    const [specializations, setSpecializations] = useState<any[]>([]);
    const [fees, setFees] = useState<any[]>([]);

    useEffect(() => {
        getAvailableRooms().then((data: any) => setRooms(data));
        getAllDepartments().then((data: any) => setDepartments(data));
        getValidConsultationFees().then((data: any) => setFees(data));
    }, []);

    const [formData, setFormData] = useState({
        firstName: '', lastName: '', email: '', phone: '', gender: 'Male', address: '',
        specialization: '', deptId: '', licenseNumber: '', consultationFee: '', joiningDate: '', roomNumber: ''
    });

    useEffect(() => {
        if (formData.deptId) {
            getValidSpecializations(formData.deptId).then((data: any) => setSpecializations(data));
            setFormData(prev => ({ ...prev, specialization: '' }));
        } else {
            setSpecializations([]);
        }
    }, [formData.deptId]);

    const handleChange = (e: any) => {
        setFormData(prev => ({ ...prev, [e.target.name]: e.target.value }));
    };

    async function handleSubmit(e: any) {
        e.preventDefault();
        setError('');

        const data = new FormData();
        Object.entries(formData).forEach(([key, value]) => data.append(key, value));

        const res = await addDoctor(data);
        if (res.success) {
            setShowModal(true);
        } else {
            setError(res.error || 'Something went wrong');
        }
    }

    return (
        <div className="max-w-3xl mx-auto relative">
            <div className="mb-8">
                <h2 className="text-2xl font-bold text-slate-800">Register New Doctor</h2>
                <p className="text-slate-500">Onboard a new specialist. License verification currently active.</p>
            </div>

            <form onSubmit={handleSubmit} className="bg-white rounded-xl border border-slate-200 shadow-sm p-8 space-y-8">
                {/* 1. Personal Information */}
                <div>
                    <h3 className="text-lg font-semibold text-slate-800 mb-4 border-b border-slate-100 pb-2 flex items-center gap-2">
                        Personal Information
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">First Name</label>
                            <input name="firstName" value={formData.firstName} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" placeholder="e.g. Tanvir" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Last Name</label>
                            <input name="lastName" value={formData.lastName} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" placeholder="e.g. Ahmed" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Email Address</label>
                            <input name="email" type="email" value={formData.email} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Mobile Number</label>
                            <input name="phone" type="tel" value={formData.phone} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" placeholder="017xxxxxxxx" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Gender</label>
                            <select name="gender" value={formData.gender} onChange={handleChange} className="w-full px-4 py-2 border border-slate-200 rounded-lg bg-white">
                                <option value="Male">Male</option>
                                <option value="Female">Female</option>
                            </select>
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Address</label>
                            <input name="address" value={formData.address} onChange={handleChange} className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" placeholder="Dhaka, Bangladesh" />
                        </div>
                    </div>
                </div>

                {/* 2. Professional Information */}
                <div>
                    <h3 className="text-lg font-semibold text-slate-800 mb-4 border-b border-slate-100 pb-2 flex items-center gap-2">
                        <Stethoscope size={20} className="text-blue-600" /> Professional Details
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Department</label>
                            <select name="deptId" value={formData.deptId} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg bg-white">
                                <option value="">Select Department...</option>
                                {departments.map(dept => (
                                    <option key={dept.dept_id} value={dept.dept_id}>{dept.name}</option>
                                ))}
                            </select>
                        </div >
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Specialization</label>
                            <select
                                name="specialization"
                                value={formData.specialization}
                                onChange={handleChange}
                                required
                                disabled={!formData.deptId}
                                className="w-full px-4 py-2 border border-slate-200 rounded-lg bg-white disabled:bg-slate-50 disabled:text-slate-400"
                            >
                                <option value="">{formData.deptId ? 'Select Specialization...' : 'Select Department First'}</option>
                                {specializations.map(s => (
                                    <option key={s.specialization_name} value={s.specialization_name}>{s.specialization_name}</option>
                                ))}
                            </select>
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">BMDC License ID</label>
                            <input name="licenseNumber" value={formData.licenseNumber} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg" placeholder="e.g. BMDC-A-12345" />
                            <p className="text-xs text-orange-600">Must be a valid ID from the registry.</p>
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Consultation Fee (BDT)</label>
                            <select name="consultationFee" value={formData.consultationFee} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg bg-white">
                                <option value="">Select Fee Tier...</option>
                                {fees.map(f => (
                                    <option key={f.amount} value={f.amount}>{f.amount} BDT</option>
                                ))}
                            </select>
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Joining Date</label>
                            <input name="joiningDate" type="date" value={formData.joiningDate} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg" />
                        </div>
                    </div>
                </div >

                {/* 3. Facility Assignment */}
                < div >
                    <h3 className="text-lg font-semibold text-slate-800 mb-4 border-b border-slate-100 pb-2 flex items-center gap-2">
                        <Building2 size={20} className="text-blue-600" /> Facility Assignment
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Assign Available Room</label>
                            <select name="roomNumber" value={formData.roomNumber} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg bg-white">
                                <option value="">Select Room...</option>
                                {rooms.length === 0 ? (
                                    <option disabled>No rooms available</option>
                                ) : rooms.map(room => (
                                    <option key={room.room_number} value={room.room_number}>
                                        {room.room_number} ({room.type})
                                    </option>
                                ))}
                            </select>
                        </div>
                    </div>
                </div >

                <div className="pt-4 flex justify-end gap-3">
                    <button type="button" onClick={() => router.back()} className="px-6 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-200 rounded-lg hover:bg-slate-50">Cancel</button>
                    <SubmitButton />
                </div>
            </form >

            {/* Success Modal */}
            {showModal && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm animate-fade-in">
                    <div className="bg-white rounded-2xl p-8 max-w-sm w-full shadow-2xl">
                        <div className="flex flex-col items-center text-center">
                            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mb-6">
                                <CheckCircle className="w-8 h-8 text-green-600" />
                            </div>
                            <h3 className="text-2xl font-bold text-slate-900 mb-2">Doctor Onboarded!</h3>
                            <p className="text-slate-600 mb-8">Registered successfully and assigned to {formData.roomNumber}.</p>
                            <button
                                onClick={() => router.push('/dashboard/doctors')}
                                className="w-full py-3 bg-slate-900 text-white rounded-xl font-medium hover:bg-slate-800 transition-colors"
                            >
                                View Doctors List
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Error Modal */}
            {error && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm animate-fade-in">
                    <div className="bg-white rounded-2xl p-8 max-w-sm w-full shadow-2xl border-2 border-red-100">
                        <div className="flex flex-col items-center text-center">
                            <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mb-6">
                                <AlertCircle className="w-8 h-8 text-red-600" />
                            </div>
                            <h3 className="text-2xl font-bold text-slate-900 mb-2">Registration Failed</h3>
                            <p className="text-slate-600 mb-8 px-4">{error}</p>
                            <button
                                onClick={() => setError('')}
                                className="w-full py-3 bg-red-600 text-white rounded-xl font-medium hover:bg-red-700 transition-colors"
                            >
                                Try Again
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

function SubmitButton() {
    const { pending } = useFormStatus()
    return (
        <button type="submit" disabled={pending} className="px-6 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50 flex items-center gap-2">
            {pending && <Loader2 className="animate-spin w-4 h-4" />}
            Register Doctor
        </button>
    )
}

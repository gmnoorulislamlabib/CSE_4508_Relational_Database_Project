'use client';

import { addPatient, getCommonMedicalProblems } from '@/lib/actions';
import { useState, useEffect } from 'react';
import { useFormStatus } from 'react-dom';
import { Loader2, CheckCircle, AlertCircle } from 'lucide-react';
import { useRouter } from 'next/navigation';

export default function NewPatientPage() {
    const router = useRouter();
    const [showModal, setShowModal] = useState(false);
    const [error, setError] = useState('');
    const [medicalProblems, setMedicalProblems] = useState<any[]>([]);
    const [selectedProblems, setSelectedProblems] = useState<string[]>([]);

    useEffect(() => {
        getCommonMedicalProblems().then((data: any) => setMedicalProblems(data));
    }, []);

    const [formData, setFormData] = useState({
        firstName: '', lastName: '', email: '', phone: '', dob: '', gender: 'Male', address: '', bloodGroup: '',
        ec_firstName: '', ec_lastName: '', ec_dob: '', ec_email: '', ec_phone: ''
    });

    const handleChange = (e: any) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    async function handleSubmit(e: any) { // Changed to standard event handler to control flow better
        e.preventDefault();
        setError('');

        // Create FormData object from state
        const data = new FormData();
        Object.entries(formData).forEach(([key, value]) => data.append(key, value));

        // Append selected medical history
        selectedProblems.forEach(p => data.append('medicalHistory', p));

        const res = await addPatient(data);
        if (res.success) {
            setShowModal(true);
        } else {
            setError(res.error || 'Something went wrong');
        }
    }

    return (
        <div className="max-w-3xl mx-auto relative">
            <div className="mb-8">
                <h2 className="text-2xl font-bold text-slate-800">Register New Patient</h2>
                <p className="text-slate-500">Create a new patient record in the system.</p>
            </div>

            {error && (
                <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center gap-3 text-red-700">
                    <AlertCircle size={20} />
                    <p>{error}</p>
                </div>
            )}

            <form onSubmit={handleSubmit} className="bg-white rounded-xl border border-slate-200 shadow-sm p-8 space-y-8">
                {/* Patient Basic Information */}
                <div>
                    <h3 className="text-lg font-semibold text-slate-800 mb-4 border-b border-slate-100 pb-2">Patient Basic Information</h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">First Name</label>
                            <input name="firstName" value={formData.firstName} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Last Name</label>
                            <input name="lastName" value={formData.lastName} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Email</label>
                            <input name="email" type="email" value={formData.email} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Phone Number</label>
                            <input name="phone" type="tel" value={formData.phone} onChange={handleChange} className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Date of Birth</label>
                            <input name="dob" type="date" value={formData.dob} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Gender</label>
                            <select name="gender" value={formData.gender} onChange={handleChange} className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all">
                                <option value="Male">Male</option>
                                <option value="Female">Female</option>
                                <option value="Other">Other</option>
                            </select>
                        </div>
                        <div className="space-y-2 md:col-span-2">
                            <label className="text-sm font-medium text-slate-700">Address</label>
                            <textarea name="address" rows={2} value={formData.address} onChange={handleChange} className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Blood Group</label>
                            <select name="bloodGroup" value={formData.bloodGroup} onChange={handleChange} className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all">
                                <option value="">Select...</option>
                                <option value="A+">A+</option>
                                <option value="A-">A-</option>
                                <option value="B+">B+</option>
                                <option value="B-">B-</option>
                                <option value="O+">O+</option>
                                <option value="O-">O-</option>
                                <option value="AB+">AB+</option>
                                <option value="AB-">AB-</option>
                            </select>
                        </div>
                    </div>
                </div>

                {/* Medical History Section */}
                <div>
                    <h3 className="text-lg font-semibold text-slate-800 mb-4 border-b border-slate-100 pb-2">Medical History</h3>
                    <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                        {medicalProblems.map((p) => (
                            <label key={p.problem_name} className={`
                                flex items-center gap-2 p-3 rounded-lg border cursor-pointer transition-all
                                ${selectedProblems.includes(p.problem_name)
                                    ? 'bg-blue-50 border-blue-200 ring-1 ring-blue-500'
                                    : 'bg-slate-50 border-slate-200 hover:bg-slate-100'}
                            `}>
                                <input
                                    type="checkbox"
                                    value={p.problem_name}
                                    checked={selectedProblems.includes(p.problem_name)}
                                    onChange={(e) => {
                                        if (e.target.checked) {
                                            setSelectedProblems([...selectedProblems, p.problem_name]);
                                        } else {
                                            setSelectedProblems(selectedProblems.filter(id => id !== p.problem_name));
                                        }
                                    }}
                                    className="w-4 h-4 text-blue-600 rounded bg-white border-slate-300 focus:ring-blue-500"
                                />
                                <span className="text-sm text-slate-700">{p.problem_name}</span>
                            </label>
                        ))}
                    </div>
                    <p className="text-xs text-slate-500 mt-2">Select all that apply to the patient's existing conditions.</p>
                </div>

                {/* Emergency Contact Information */}
                <div>
                    <h3 className="text-lg font-semibold text-slate-800 mb-4 border-b border-slate-100 pb-2">Emergency Contact Information</h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">First Name</label>
                            <input name="ec_firstName" value={formData.ec_firstName} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Last Name</label>
                            <input name="ec_lastName" value={formData.ec_lastName} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Date of Birth</label>
                            <input name="ec_dob" type="date" value={formData.ec_dob} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Email</label>
                            <input name="ec_email" type="email" value={formData.ec_email} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-slate-700">Mobile Number</label>
                            <input name="ec_phone" type="tel" value={formData.ec_phone} onChange={handleChange} required className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all" />
                        </div>
                    </div>
                </div>

                <div className="pt-4 flex justify-end gap-3">
                    <button type="button" onClick={() => window.history.back()} className="px-6 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-200 rounded-lg hover:bg-slate-50">Cancel</button>
                    <SubmitButton />
                </div>
            </form>

            {/* Success Modal */}
            {showModal && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm animate-fade-in">
                    <div className="bg-white rounded-2xl p-8 max-w-sm w-full shadow-2xl transform transition-all scale-100">
                        <div className="flex flex-col items-center text-center">
                            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mb-6">
                                <CheckCircle className="w-8 h-8 text-green-600" />
                            </div>
                            <h3 className="text-2xl font-bold text-slate-900 mb-2">Success!</h3>
                            <p className="text-slate-600 mb-8">Patient has been registered securely in the database.</p>

                            <div className="flex flex-col gap-3 w-full">
                                <button
                                    onClick={() => router.push('/dashboard/patients')}
                                    className="w-full py-3 bg-slate-900 text-white rounded-xl font-medium hover:bg-slate-800 transition-colors"
                                >
                                    View Patient List
                                </button>
                                <button
                                    onClick={() => {
                                        setShowModal(false);
                                        // Optional: Reset form here if possible or reload
                                        window.location.reload();
                                    }}
                                    className="w-full py-3 bg-white text-slate-700 border border-slate-200 rounded-xl font-medium hover:bg-slate-50 transition-colors"
                                >
                                    Register Another
                                </button>
                            </div>
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
            Register Patient
        </button>
    )
}

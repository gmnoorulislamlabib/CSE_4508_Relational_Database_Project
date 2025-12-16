'use client';

import { useState } from 'react';
import { Search, ShoppingCart, Plus, Minus, Trash2, X } from 'lucide-react';
import { createPharmacySale } from '@/lib/actions';
import { useRouter } from 'next/navigation';

export default function SellMedicineModal({
    isOpen,
    onClose,
    medicines,
    patients
}: {
    isOpen: boolean,
    onClose: () => void,
    medicines: any[],
    patients: any[]
}) {
    const [selectedPatient, setSelectedPatient] = useState<string>('');
    const [searchMed, setSearchMed] = useState('');
    const [cart, setCart] = useState<any[]>([]);
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [notification, setNotification] = useState<{ message: string, type: 'error' | 'success' } | null>(null);
    const router = useRouter();

    if (!isOpen) return null;

    const showNotification = (message: string, type: 'error' | 'success' = 'error') => {
        setNotification({ message, type });
        setTimeout(() => setNotification(null), 3000);
    };

    const filteredMeds = medicines.filter(m =>
        m.name.toLowerCase().includes(searchMed.toLowerCase()) &&
        !cart.find(item => item.medicine_id === m.medicine_id)
    );

    const addToCart = (med: any) => {
        if (med.stock_quantity < 1) return showNotification("Item is out of stock!");
        setCart([...cart, { ...med, quantity: 1 }]);
    };

    const updateQuantity = (id: number, delta: number) => {
        setCart(cart.map(item => {
            if (item.medicine_id === id) {
                const newQty = item.quantity + delta;
                if (newQty > item.stock_quantity) {
                    showNotification(`Max available stock is ${item.stock_quantity}`);
                    return item;
                }
                return { ...item, quantity: Math.max(1, newQty) };
            }
            return item;
        }));
    };

    const removeFromCart = (id: number) => {
        setCart(cart.filter(item => item.medicine_id !== id));
    };

    const totalAmount = cart.reduce((sum, item) => sum + (item.quantity * item.unit_price), 0);

    const handleCheckout = async () => {
        if (!selectedPatient) return showNotification("Please select a patient to proceed.");
        if (cart.length === 0) return showNotification("Cart is empty. Add medicines first.");

        setIsSubmitting(true);
        const orderItems = cart.map(item => ({
            medicineId: item.medicine_id,
            quantity: item.quantity,
            price: item.unit_price
        }));

        const res = await createPharmacySale(parseInt(selectedPatient), orderItems);
        setIsSubmitting(false);

        if (res.success) {
            onClose();
            setCart([]);
            setSelectedPatient('');
            router.push(`/dashboard/billing/${res.invoiceId}`);
        } else {
            showNotification(res.error || "Failed to create order.");
        }
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4 animate-in fade-in zoom-in duration-200">
            <div className="bg-white rounded-xl shadow-2xl w-full max-w-4xl h-[80vh] flex overflow-hidden relative">

                {/* Notification Toast */}
                {notification && (
                    <div className={`absolute top-6 right-6 z-50 max-w-xs bg-white border-l-4 shadow-2xl rounded-r-lg p-4 flex items-center gap-3 animate-in slide-in-from-right-8 fade-in duration-300
                        ${notification.type === 'error' ? 'border-red-500' : 'border-emerald-500'}`}>
                        <div className={`flex-shrink-0 p-2 rounded-full ${notification.type === 'error' ? 'bg-red-50 text-red-500' : 'bg-emerald-50 text-emerald-500'}`}>
                            {notification.type === 'error' ? <Plus className="rotate-45" size={16} /> : <Plus size={16} />}
                        </div>
                        <div>
                            <h4 className={`font-bold text-sm ${notification.type === 'error' ? 'text-red-600' : 'text-emerald-600'}`}>
                                {notification.type === 'error' ? 'Error' : 'Success'}
                            </h4>
                            <p className="text-slate-600 text-xs mt-0.5 leading-relaxed">
                                {notification.message}
                            </p>
                        </div>
                    </div>
                )}

                {/* Left: Product Selection */}
                <div className="w-1/2 p-6 border-r border-slate-200 flex flex-col bg-slate-50">
                    <h3 className="text-xl font-bold text-slate-800 mb-4">Select Medicines</h3>

                    <div className="relative mb-4">
                        <Search className="absolute left-3 top-3 text-slate-400" size={18} />
                        <input
                            type="text"
                            placeholder="Search medicine..."
                            className="w-full pl-10 pr-4 py-2 rounded-lg border border-slate-300 focus:ring-2 focus:ring-blue-500 outline-none"
                            value={searchMed}
                            onChange={(e) => setSearchMed(e.target.value)}
                        />
                    </div>

                    <div className="flex-1 overflow-y-auto space-y-2 pr-2">
                        {filteredMeds.map(med => (
                            <div key={med.medicine_id} className="bg-white p-3 rounded-lg border border-slate-200 flex justify-between items-center shadow-sm">
                                <div>
                                    <h4 className="font-semibold text-slate-800">{med.name}</h4>
                                    <div className="flex gap-2 text-xs text-slate-500">
                                        <span>Stock: {med.stock_quantity}</span>
                                        <span>•</span>
                                        <span>৳{med.unit_price}</span>
                                    </div>
                                </div>
                                <button
                                    onClick={() => addToCart(med)}
                                    disabled={med.stock_quantity < 1}
                                    className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 disabled:opacity-50"
                                >
                                    <Plus size={16} />
                                </button>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Right: Cart & Checkout */}
                <div className="w-1/2 p-6 flex flex-col">
                    <div className="flex justify-between items-start mb-6">
                        <h3 className="text-xl font-bold text-slate-800">New Order</h3>
                        <button onClick={onClose} className="text-slate-400 hover:text-slate-600 font-bold text-xl">
                            <X size={24} />
                        </button>
                    </div>

                    <div className="mb-4">
                        <label className="block text-sm font-medium text-slate-700 mb-1">Select Patient</label>
                        <select
                            className="w-full p-2 border border-slate-300 rounded-lg outline-none focus:ring-2 focus:ring-blue-500"
                            value={selectedPatient}
                            onChange={(e) => setSelectedPatient(e.target.value)}
                        >
                            <option value="">-- Choose Patient --</option>
                            {patients.map(p => (
                                <option key={p.patient_id} value={p.patient_id}>{p.name}</option>
                            ))}
                        </select>
                    </div>

                    <div className="flex-1 overflow-y-auto border-t border-b border-slate-100 py-2 space-y-3">
                        {cart.length === 0 ? (
                            <div className="h-full flex items-center justify-center text-slate-400 italic">
                                Cart is empty
                            </div>
                        ) : cart.map(item => (
                            <div key={item.medicine_id} className="flex items-center justify-between">
                                <div className="flex-1">
                                    <h5 className="font-medium text-slate-800">{item.name}</h5>
                                    <p className="text-xs text-slate-500">৳{item.unit_price} x {item.quantity}</p>
                                </div>
                                <div className="flex items-center gap-2">
                                    <button
                                        onClick={() => updateQuantity(item.medicine_id, -1)}
                                        className="p-1 text-slate-400 hover:text-blue-600 rounded"
                                    >
                                        <Minus size={14} />
                                    </button>
                                    <span className="text-sm font-bold w-4 text-center">{item.quantity}</span>
                                    <button
                                        onClick={() => updateQuantity(item.medicine_id, 1)}
                                        className="p-1 text-slate-400 hover:text-blue-600 rounded"
                                    >
                                        <Plus size={14} />
                                    </button>
                                    <button
                                        onClick={() => removeFromCart(item.medicine_id)}
                                        className="ml-2 text-red-400 hover:text-red-600"
                                    >
                                        <Trash2 size={16} />
                                    </button>
                                </div>
                                <div className="w-16 text-right font-medium text-slate-900">
                                    ৳{item.unit_price * item.quantity}
                                </div>
                            </div>
                        ))}
                    </div>

                    <div className="mt-4 pt-4 border-t border-slate-200">
                        <div className="flex justify-between items-center text-lg font-bold text-slate-900 mb-4">
                            <span>Total</span>
                            <span>৳{totalAmount.toFixed(2)}</span>
                        </div>
                        <button
                            onClick={handleCheckout}
                            disabled={isSubmitting || cart.length === 0}
                            className="w-full py-3 bg-blue-600 text-white rounded-xl hover:bg-blue-700 font-bold shadow-lg shadow-blue-600/20 disabled:opacity-50 flex items-center justify-center gap-2"
                        >
                            <ShoppingCart size={20} />
                            {isSubmitting ? 'Processing...' : 'Create Order & Invoice'}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}

import { getInvoiceDetails, processPayment } from '@/lib/actions';
import { notFound } from 'next/navigation';
import { Printer, CreditCard } from 'lucide-react';
import Link from 'next/link';

export default async function InvoiceDetailsPage({ params }: { params: Promise<{ id: string }> }) {
    // await the params before using them (Next.js 15 fix)
    const { id } = await params;

    // Correctly await the params before accessing properties, or use it directly as promise (but Next.js usually passes as promise now or direct object? 
    // Wait, in Next 15 params IS a promise. But if this is Next 14, it is an object. 
    // Let's assume params is a promise as per error messages often seen or standard patterns. 
    // Actually, in the latest types, it is Promise<{ id: string }>.

    const invoice = await getInvoiceDetails(id);

    if (!invoice) return notFound();

    return (
        <div className="max-w-4xl mx-auto space-y-8 animate-fade-in p-8 bg-white border border-slate-200 rounded-xl shadow-sm my-8">
            {/* Header */}
            <div className="flex justify-between items-start border-b border-slate-200 pb-8">
                <div>
                    <h1 className="text-3xl font-bold text-slate-900 tracking-tight">INVOICE</h1>
                    <p className="text-slate-500 mt-1">#{invoice.invoice_id}</p>
                    <div className="mt-4 text-sm text-slate-500">
                        <p>Issued: {new Date(invoice.generated_at).toLocaleDateString()}</p>
                        <p>Status: <span className={`font-bold ${invoice.status === 'Paid' ? 'text-emerald-600' : 'text-amber-500'}`}>{invoice.status}</span></p>
                    </div>
                </div>
                <div className="text-right">
                    <h2 className="text-xl font-bold text-slate-800">CareConnect Hospital</h2>
                    <p className="text-slate-500 text-sm mt-1">123 Health Avenue, Dhaka</p>
                    <p className="text-slate-500 text-sm">contact@careconnect.com</p>
                </div>
            </div>

            {/* Patient Info */}
            <div className="grid grid-cols-2 gap-8">
                <div>
                    <h3 className="text-sm uppercase font-bold text-slate-500 mb-2">Bill To</h3>
                    <p className="font-bold text-slate-900 text-lg">{invoice.patient_name}</p>
                    <p className="text-slate-600">{invoice.phone_number}</p>
                    <p className="text-slate-600 text-sm max-w-xs">{invoice.address}</p>
                </div>
                {/* Could add Payment Info if Paid */}
            </div>

            {/* Line Items */}
            <table className="w-full text-left">
                <thead className="bg-slate-50 border-y border-slate-200">
                    <tr>
                        <th className="py-3 px-4 text-sm font-semibold text-slate-600">Description</th>
                        <th className="py-3 px-4 text-sm font-semibold text-slate-600 text-right">Qty</th>
                        <th className="py-3 px-4 text-sm font-semibold text-slate-600 text-right">Unit Price</th>
                        <th className="py-3 px-4 text-sm font-semibold text-slate-600 text-right">Total</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                    {invoice.items.map((item: any, i: number) => (
                        <tr key={i}>
                            <td className="py-4 px-4 text-slate-800 font-medium">{item.description}</td>
                            <td className="py-4 px-4 text-slate-600 text-right">{item.quantity}</td>
                            <td className="py-4 px-4 text-slate-600 text-right">৳{item.unit_price}</td>
                            <td className="py-4 px-4 text-slate-900 font-bold text-right">৳{item.total}</td>
                        </tr>
                    ))}
                </tbody>
            </table>

            {/* Total */}
            <div className="flex justify-end border-t border-slate-200 pt-6">
                <div className="text-right space-y-2">
                    <div className="flex justify-between w-64 text-slate-600">
                        <span>Subtotal:</span>
                        <span>৳{invoice.total_amount}</span>
                    </div>
                    {/* Discount logic could go here */}
                    <div className="flex justify-between w-64 text-2xl font-bold text-slate-900 border-t border-slate-200 pt-2">
                        <span>Total:</span>
                        <span>৳{invoice.total_amount}</span>
                    </div>
                </div>
            </div>

            {/* Actions */}
            <div className="flex justify-end gap-4 pt-8 border-t border-slate-100 no-print">
                {invoice.status !== 'Paid' && (
                    <form action={async () => {
                        'use server';
                        await processPayment(invoice.invoice_id, invoice.total_amount, 'Cash');
                    }}>
                        <button className="px-6 py-2 bg-slate-900 text-white rounded-lg font-bold hover:bg-slate-800 flex items-center gap-2 shadow-lg shadow-slate-900/20">
                            <CreditCard size={18} /> Pay Now (Cash)
                        </button>
                    </form>
                )}
            </div>
        </div>
    );
}

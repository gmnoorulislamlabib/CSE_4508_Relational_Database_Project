'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  HeartPulse,
  Lock,
  Mail,
  ArrowRight,
  Loader2,
  ShieldCheck,
  UserCog,
  ChevronLeft
} from 'lucide-react';
import { verifyLogin } from '@/lib/actions';

type Role = 'Admin' | 'Receptionist' | null;

export default function LoginPage() {
  const router = useRouter();

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [selectedRole, setSelectedRole] = useState<Role>(null);

  async function handleLogin(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (loading) return; // hard guard against double submit

    setLoading(true);
    setError('');

    try {
      const formData = new FormData(e.currentTarget);
      formData.set('role', selectedRole ?? '');

      const res = await verifyLogin(formData);

      if (!res?.success) {
        throw new Error(res?.error || 'Login failed');
      }

      router.push('/dashboard');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unexpected error occurred');
    } finally {
      setLoading(false);
    }
  }

  /* ======================
     ROLE SELECTION SCREEN
     ====================== */

  if (!selectedRole) {
    return (
      <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-4">
        <div className="mb-12 flex flex-col items-center animate-fade-in-down">
          <div className="relative">
            <div className="absolute inset-0 blur-xl bg-blue-500/30 rounded-full" />
            <div className="relative bg-blue-600 p-4 rounded-2xl shadow-lg">
              <HeartPulse className="w-10 h-10 text-white" />
            </div>
          </div>

          <h1 className="text-4xl font-bold text-slate-900 tracking-tight mt-6">
            CareConnect
          </h1>
          <p className="text-slate-500 mt-3 text-lg">
            Select your portal to continue
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 w-full max-w-3xl animate-fade-in-up">
          {/* ADMIN */}
          <button
            onClick={() => {
              setSelectedRole('Admin');
              setError('');
            }}
            className="group relative bg-white p-8 rounded-2xl shadow-md border-2 border-slate-100 hover:border-blue-500 hover:shadow-xl transition-all duration-300 text-left focus:outline-none focus:ring-4 focus:ring-blue-500/20"
          >
            <div className="absolute top-6 right-6 p-2 bg-blue-50 text-blue-600 rounded-lg group-hover:bg-blue-600 group-hover:text-white transition-colors">
              <ArrowRight className="w-6 h-6" />
            </div>
            <div className="p-4 bg-slate-100 w-fit rounded-xl mb-6 group-hover:scale-110 transition-transform">
              <ShieldCheck className="w-8 h-8 text-slate-700" />
            </div>
            <h3 className="text-2xl font-bold text-slate-900 mb-2">
              Administrator
            </h3>
            <p className="text-slate-500">
              Manage doctors, view earnings, and oversee hospital operations.
            </p>
          </button>

          {/* RECEPTIONIST */}
          <button
            onClick={() => {
              setSelectedRole('Receptionist');
              setError('');
            }}
            className="group relative bg-white p-8 rounded-2xl shadow-md border-2 border-slate-100 hover:border-emerald-500 hover:shadow-xl transition-all duration-300 text-left focus:outline-none focus:ring-4 focus:ring-emerald-500/20"
          >
            <div className="absolute top-6 right-6 p-2 bg-emerald-50 text-emerald-600 rounded-lg group-hover:bg-emerald-600 group-hover:text-white transition-colors">
              <ArrowRight className="w-6 h-6" />
            </div>
            <div className="p-4 bg-slate-100 w-fit rounded-xl mb-6 group-hover:scale-110 transition-transform">
              <UserCog className="w-8 h-8 text-slate-700" />
            </div>
            <h3 className="text-2xl font-bold text-slate-900 mb-2">
              Receptionist
            </h3>
            <p className="text-slate-500">
              Manage patients, appointments, and room bookings.
            </p>
          </button>
        </div>
      </div>
    );
  }

  /* ======================
     LOGIN FORM
     ====================== */

  const isAdmin = selectedRole === 'Admin';

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-4 relative">
      <button
        onClick={() => setSelectedRole(null)}
        className="absolute top-8 left-8 flex items-center gap-2 text-slate-500 hover:text-slate-900 transition-colors font-medium"
      >
        <ChevronLeft className="w-5 h-5" />
        Back
      </button>

      <div className="mb-8 flex flex-col items-center animate-fade-in-down">
        <div
          className={`relative p-3 rounded-2xl shadow-lg mb-4 ${
            isAdmin
              ? 'bg-blue-600 shadow-blue-500/30'
              : 'bg-emerald-600 shadow-emerald-500/30'
          }`}
        >
          {isAdmin ? (
            <ShieldCheck className="w-8 h-8 text-white" />
          ) : (
            <UserCog className="w-8 h-8 text-white" />
          )}
        </div>

        <h1 className="text-3xl font-bold text-slate-900">
          {selectedRole} Portal
        </h1>
        <p className="text-slate-500 mt-2">
          Enter credentials to access dashboard
        </p>
      </div>

      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl border border-slate-200 overflow-hidden animate-fade-in-up">
        <div className="p-8">
          <form onSubmit={handleLogin} className="space-y-5">
            <input type="hidden" name="role" value={selectedRole} />

            {/* EMAIL */}
            <div>
              <label className="text-sm font-semibold text-slate-700 ml-1">
                Email Address
              </label>
              <div className="relative mt-2">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                <input
                  name="email"
                  type="email"
                  required
                  aria-label="Email address"
                  className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none font-medium"
                  defaultValue={
                    isAdmin
                      ? 'admin@careconnect.bd'
                      : 'reception@careconnect.bd'
                  }
                />
              </div>
            </div>

            {/* PASSWORD */}
            <div>
              <label className="text-sm font-semibold text-slate-700 ml-1">
                Password
              </label>
              <div className="relative mt-2">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 w-5 h-5" />
                <input
                  name="password"
                  type="password"
                  required
                  aria-label="Password"
                  className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none font-medium"
                  defaultValue="123456"
                />
              </div>
            </div>

            {error && (
              <div
                role="alert"
                className="p-3 bg-red-50 text-red-600 text-sm rounded-lg font-medium text-center animate-shake"
              >
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className={`w-full py-3.5 text-white rounded-xl font-bold shadow-lg transition-all flex items-center justify-center gap-2 ${
                isAdmin
                  ? 'bg-blue-600 hover:bg-blue-700 shadow-blue-500/30'
                  : 'bg-emerald-600 hover:bg-emerald-700 shadow-emerald-500/30'
              } disabled:opacity-70 disabled:cursor-not-allowed`}
            >
              {loading ? (
                <Loader2 className="w-5 h-5 animate-spin" />
              ) : (
                <>
                  Login as {selectedRole}
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

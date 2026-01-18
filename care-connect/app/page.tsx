'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  ArrowRight,
  ShieldCheck,
  UserCog,
  Lock,
  Mail,
  ChevronLeft,
  Loader2,
  Sparkles,
  HeartPulse,
  Zap,
} from 'lucide-react';

import { verifyLogin } from '@/lib/actions';

/* ----------------------------- TYPES ----------------------------- */

type Role = 'Admin' | 'Receptionist' | null;

/* ------------------------- PARTICLE CANVAS ------------------------ */
/*
  Ultra-simple particle engine.
  Runs uncontrolled.
  Eats GPU.
  Looks cool.
*/
function ParticleBackground() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current!;
    const ctx = canvas.getContext('2d')!;
    let width = (canvas.width = window.innerWidth);
    let height = (canvas.height = window.innerHeight);

    const particles = Array.from({ length: 120 }).map(() => ({
      x: Math.random() * width,
      y: Math.random() * height,
      vx: (Math.random() - 0.5) * 0.6,
      vy: (Math.random() - 0.5) * 0.6,
      r: Math.random() * 2 + 0.5,
    }));

    function loop() {
      ctx.clearRect(0, 0, width, height);

      for (const p of particles) {
        p.x += p.vx;
        p.y += p.vy;

        if (p.x < 0 || p.x > width) p.vx *= -1;
        if (p.y < 0 || p.y > height) p.vy *= -1;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(255,255,255,0.6)';
        ctx.fill();
      }

      requestAnimationFrame(loop);
    }

    loop();

    window.addEventListener('resize', () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    });
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 z-0 pointer-events-none"
    />
  );
}

/* --------------------------- MAIN PAGE ---------------------------- */

export default function LoginPageFlashy() {
  const router = useRouter();

  const [role, setRole] = useState<Role>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [bootText, setBootText] = useState<string[]>([]);

  /* ----------------------- FAKE BOOT SEQUENCE ---------------------- */
  useEffect(() => {
    const lines = [
      '[SYSTEM] Initializing CareConnect Core...',
      '[OK] Secure memory allocated',
      '[OK] Auth subsystem online',
      '[OK] Hospital graph loaded',
      '[READY] Awaiting operator input...',
    ];

    let i = 0;
    const interval = setInterval(() => {
      setBootText((t) => [...t, lines[i]]);
      i++;
      if (i >= lines.length) clearInterval(interval);
    }, 220);

    return () => clearInterval(interval);
  }, []);

  /* --------------------------- LOGIN --------------------------- */
  async function handleLogin(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setError('');

    const formData = new FormData(e.currentTarget);
    const res = await verifyLogin(formData);

    if (res.success) {
      setTimeout(() => router.push('/dashboard'), 1200);
    } else {
      setError(res.error || 'AUTHENTICATION FAILURE');
      setLoading(false);
    }
  }

  /* ----------------------- ROLE SELECTION ---------------------- */

  if (!role) {
    return (
      <div className="relative min-h-screen overflow-hidden bg-black text-white">
        <ParticleBackground />

        {/* Neon Gradient Overlay */}
        <div className="absolute inset-0 bg-gradient-to-br from-blue-900/40 via-purple-900/40 to-emerald-900/40 animate-pulse" />

        {/* Boot Console */}
        <div className="relative z-10 max-w-3xl mx-auto pt-20 px-6">
          <div className="font-mono text-sm bg-black/60 backdrop-blur-xl border border-white/10 rounded-xl p-6 shadow-[0_0_40px_rgba(0,255,255,0.15)]">
            {bootText.map((line, i) => (
              <div key={i} className="text-emerald-400">
                {line}
              </div>
            ))}
          </div>
        </div>

        {/* App Title */}
        <div className="relative z-10 mt-16 flex flex-col items-center">
          <div className="p-6 rounded-full bg-gradient-to-br from-cyan-500 to-purple-600 shadow-[0_0_60px_rgba(0,255,255,0.6)] animate-spin-slow">
            <HeartPulse className="w-10 h-10 text-white" />
          </div>

          <h1 className="mt-6 text-6xl font-black tracking-tight bg-gradient-to-r from-cyan-300 via-purple-300 to-emerald-300 bg-clip-text text-transparent">
            CareConnect
          </h1>

          <p className="mt-4 text-white/70 text-lg">
            Neural Hospital Access Interface
          </p>
        </div>

        {/* Role Cards */}
        <div className="relative z-10 mt-20 grid grid-cols-1 md:grid-cols-2 gap-10 max-w-5xl mx-auto px-6">
          {/* ADMIN */}
          <button
            onClick={() => setRole('Admin')}
            className="group relative overflow-hidden rounded-3xl border border-cyan-400/30 bg-white/5 backdrop-blur-2xl p-10 text-left shadow-[0_0_80px_rgba(0,255,255,0.2)] hover:shadow-[0_0_120px_rgba(0,255,255,0.6)] transition-all duration-700"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/20 to-blue-800/20 opacity-0 group-hover:opacity-100 transition-opacity" />
            <ShieldCheck className="w-12 h-12 text-cyan-300 mb-6" />
            <h3 className="text-3xl font-bold">Administrator</h3>
            <p className="mt-3 text-white/60">
              Full system authority. Financials. Doctors. Infrastructure.
            </p>
            <div className="mt-6 flex items-center gap-2 text-cyan-300">
              Enter Portal <ArrowRight />
            </div>
          </button>

          {/* RECEPTIONIST */}
          <button
            onClick={() => setRole('Receptionist')}
            className="group relative overflow-hidden rounded-3xl border border-emerald-400/30 bg-white/5 backdrop-blur-2xl p-10 text-left shadow-[0_0_80px_rgba(0,255,150,0.2)] hover:shadow-[0_0_120px_rgba(0,255,150,0.6)] transition-all duration-700"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-emerald-500/20 to-teal-800/20 opacity-0 group-hover:opacity-100 transition-opacity" />
            <UserCog className="w-12 h-12 text-emerald-300 mb-6" />
            <h3 className="text-3xl font-bold">Receptionist</h3>
            <p className="mt-3 text-white/60">
              Patients. Scheduling. Front-desk operations.
            </p>
            <div className="mt-6 flex items-center gap-2 text-emerald-300">
              Enter Portal <ArrowRight />
            </div>
          </button>
        </div>
      </div>
    );
  }

  /* -------------------------- LOGIN UI -------------------------- */

  return (
    <div className="relative min-h-screen bg-black text-white overflow-hidden">
      <ParticleBackground />

      {/* Back */}
      <button
        onClick={() => setRole(null)}
        className="absolute z-20 top-8 left-8 flex items-center gap-2 text-white/60 hover:text-white"
      >
        <ChevronLeft />
        Abort Authentication
      </button>

      {/* Login Card */}
      <div className="relative z-10 flex min-h-screen items-center justify-center px-6">
        <div className="w-full max-w-lg rounded-3xl border border-white/10 bg-white/5 backdrop-blur-3xl p-10 shadow-[0_0_120px_rgba(255,255,255,0.15)]">
          <div className="flex items-center justify-center mb-8 gap-3">
            {role === 'Admin' ? (
              <ShieldCheck className="w-10 h-10 text-cyan-400" />
            ) : (
              <UserCog className="w-10 h-10 text-emerald-400" />
            )}
            <h2 className="text-3xl font-black">{role} Access</h2>
          </div>

          <form onSubmit={handleLogin} className="space-y-6">
            <div>
              <label className="text-xs uppercase tracking-widest text-white/50">
                Email
              </label>
              <div className="relative mt-2">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-white/40" />
                <input
                  name="email"
                  required
                  defaultValue={
                    role === 'Admin'
                      ? 'admin@careconnect.bd'
                      : 'reception@careconnect.bd'
                  }
                  className="w-full rounded-xl bg-black/40 border border-white/10 py-3 pl-12 pr-4 outline-none focus:border-cyan-400"
                />
              </div>
            </div>

            <div>
              <label className="text-xs uppercase tracking-widest text-white/50">
                Password
              </label>
              <div className="relative mt-2">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-white/40" />
                <input
                  name="password"
                  type="password"
                  required
                  defaultValue="123456"
                  className="w-full rounded-xl bg-black/40 border border-white/10 py-3 pl-12 pr-4 outline-none focus:border-cyan-400"
                />
              </div>
            </div>

            {error && (
              <div className="text-red-400 text-center font-mono">
                {error}
              </div>
            )}

            <button
              disabled={loading}
              className="w-full mt-4 flex items-center justify-center gap-3 rounded-xl py-4 font-black tracking-wide bg-gradient-to-r from-cyan-500 via-purple-500 to-emerald-500 shadow-[0_0_60px_rgba(0,255,255,0.6)] hover:scale-[1.03] transition-all"
            >
              {loading ? (
                <Loader2 className="animate-spin" />
              ) : (
                <>
                  INITIATE LOGIN
                  <Zap />
                </>
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

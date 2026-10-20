'use client';

import { useState, useRef, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { kpis, cashFlow, transactions, products } from '../lib/demoData';

function formatEur(n: number) {
  return n.toLocaleString('sk-SK', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
}

export default function App() {
  const [tab, setTab] = useState<'dashboard' | 'market'>('dashboard');
  const [profileOpen, setProfileOpen] = useState(false);
  const [notifOpen, setNotifOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [type, setType] = useState<'all' | 'system' | 'firm'>('all');
  const profileRef = useRef<HTMLDivElement>(null);
  const notifRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (profileRef.current && !profileRef.current.contains(e.target as Node)) setProfileOpen(false);
      if (notifRef.current && !notifRef.current.contains(e.target as Node)) setNotifOpen(false);
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  const filtered = products.filter((p) => {
    const matchQuery = p.name.toLowerCase().includes(query.toLowerCase());
    const matchType = type === 'all' || p.type === type;
    return matchQuery && matchType;
  });

  const title = tab === 'dashboard' ? 'Prehľad' : 'Trh';

  return (
    <div className="flex min-h-screen bg-slate-50">
      {/* Sidebar */}
      <aside className="w-64 bg-[#0c1222] text-slate-300 flex flex-col min-h-screen shrink-0 border-r border-slate-800/60">
        <div className="px-5 py-5 flex items-center gap-2.5">
          <div className="w-7 h-7 rounded-md bg-blue-600 flex items-center justify-center">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5">
              <path d="M3 3v18h18" /><path d="M7 14l4-4 4 4 5-5" />
            </svg>
          </div>
          <span className="font-semibold text-white text-[15px]">SimuCorp</span>
        </div>
        <nav className="flex-1 px-3 py-2 space-y-0.5">
          <button onClick={() => setTab('dashboard')} className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-medium transition ${tab === 'dashboard' ? 'bg-slate-800 text-white' : 'text-slate-300 hover:bg-slate-800/60'}`}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>
            Prehľad
          </button>
          <button onClick={() => setTab('market')} className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-medium transition ${tab === 'market' ? 'bg-slate-800 text-white' : 'text-slate-300 hover:bg-slate-800/60'}`}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
            Trh
          </button>
        </nav>
        <div className="px-3 py-3 border-t border-slate-800/60">
          <button className="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm text-slate-400 hover:bg-slate-800/50">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
            Nastavenia
          </button>
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-w-0">
        {/* TopBar */}
        <header className="h-14 bg-[#0c1222] border-b border-slate-800/60 flex items-center justify-between px-6 shrink-0">
          <h1 className="text-white font-medium text-[15px]">{title}</h1>
          <div className="flex items-center gap-3">
            <div className="relative" ref={notifRef}>
              <button onClick={() => { setNotifOpen(!notifOpen); setProfileOpen(false); }} className="relative p-1.5 rounded-md hover:bg-slate-800/60 text-slate-400 hover:text-slate-200">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
                <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full" />
              </button>
              {notifOpen && (
                <div className="absolute right-0 top-full mt-2 w-72 bg-white rounded-lg shadow-lg border border-slate-200 py-2 z-50">
                  <div className="px-4 py-2 text-xs font-medium text-slate-500 uppercase">Notifikácie</div>
                  <div className="px-4 py-3 text-sm text-slate-600 border-t">Žiadne nové notifikácie</div>
                </div>
              )}
            </div>
            <div className="relative" ref={profileRef}>
              <button onClick={() => { setProfileOpen(!profileOpen); setNotifOpen(false); }} className="flex items-center gap-2 text-slate-400 hover:text-slate-200">
                <div className="w-7 h-7 rounded-full bg-slate-700 flex items-center justify-center text-xs text-white font-medium">A</div>
                <span className="hidden sm:inline text-sm">Profil</span>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="6 9 12 15 18 9"/></svg>
              </button>
              {profileOpen && (
                <div className="absolute right-0 top-full mt-2 w-48 bg-white rounded-lg shadow-lg border border-slate-200 py-1 z-50">
                  <button className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50">Môj účet</button>
                  <button className="w-full text-left px-4 py-2 text-sm text-slate-700 hover:bg-slate-50">Nastavenia</button>
                  <div className="border-t my-1" />
                  <button className="w-full text-left px-4 py-2 text-sm text-rose-600 hover:bg-rose-50">Odhlásiť sa</button>
                </div>
              )}
            </div>
          </div>
        </header>

        <main className="flex-1 p-6 lg:p-8 overflow-auto">
          {tab === 'dashboard' ? (
            <div className="space-y-6">
              <p className="text-sm text-slate-500">Firma Alfa · Trieda 3.A</p>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <Kpi title="Hotovosť" value={formatEur(kpis.cash)} hint="+4,2 % oproti minulému týždňu" />
                <Kpi title="Tržby" value={formatEur(kpis.revenue)} hint="Celkové tržby" />
                <Kpi title="Hodnota zásob" value={formatEur(kpis.inventoryValue)} hint="Vážený priemer" />
                <Kpi title="Obchody" value={String(kpis.trades)} hint="Dokončené transakcie" />
              </div>
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                <div className="lg:col-span-2 bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
                  <h2 className="text-sm font-medium text-slate-700 mb-4">Vývoj hotovosti</h2>
                  <div className="h-64">
                    <ResponsiveContainer width="100%" height="100%">
                      <LineChart data={cashFlow}>
                        <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
                        <XAxis dataKey="month" tick={{ fontSize: 12 }} stroke="#94a3b8" />
                        <YAxis tick={{ fontSize: 12 }} stroke="#94a3b8" />
                        <Tooltip formatter={(v: number) => formatEur(v)} />
                        <Line type="monotone" dataKey="value" stroke="#1d4ed8" strokeWidth={2} dot={false} />
                      </LineChart>
                    </ResponsiveContainer>
                  </div>
                </div>
                <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
                  <h2 className="text-sm font-medium text-slate-700 mb-4">Rýchle akcie</h2>
                  <div className="space-y-2">
                    <button className="w-full text-left px-3 py-2.5 rounded-lg bg-slate-50 hover:bg-slate-100 text-sm font-medium">Vystaviť ponuku</button>
                    <button className="w-full text-left px-3 py-2.5 rounded-lg bg-slate-50 hover:bg-slate-100 text-sm font-medium">Kúpiť zo systému</button>
                    <button className="w-full text-left px-3 py-2.5 rounded-lg bg-slate-50 hover:bg-slate-100 text-sm font-medium">Zobraziť sklad</button>
                    <button onClick={() => setTab('market')} className="w-full text-left px-3 py-2.5 rounded-lg bg-blue-600 text-white text-sm font-medium hover:bg-blue-700">Prejsť na trh</button>
                  </div>
                </div>
              </div>
              <div className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">
                <div className="px-5 py-4 border-b border-slate-100"><h2 className="text-sm font-medium text-slate-700">Posledné transakcie</h2></div>
                <table className="w-full text-sm">
                  <thead><tr className="text-left text-xs text-slate-500 uppercase border-b"><th className="px-5 py-3">Dátum</th><th className="px-5 py-3">Popis</th><th className="px-5 py-3">Kategória</th><th className="px-5 py-3 text-right">Suma</th></tr></thead>
                  <tbody>
                    {transactions.map(t => (
                      <tr key={t.id} className="border-b border-slate-50 last:border-0 hover:bg-slate-50/60">
                        <td className="px-5 py-3 text-slate-600">{t.date}</td>
                        <td className="px-5 py-3 font-medium">{t.description}</td>
                        <td className="px-5 py-3 text-slate-600">{t.category}</td>
                        <td className={`px-5 py-3 text-right font-medium ${t.amount >= 0 ? 'text-emerald-600' : 'text-rose-600'}`}>{t.amount >= 0 ? '+' : ''}{formatEur(t.amount)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              <p className="text-sm text-slate-500">Aktívne ponuky v triede</p>
              <div className="flex flex-col sm:flex-row gap-3">
                <input value={query} onChange={e => setQuery(e.target.value)} placeholder="Hľadať produkt…" className="flex-1 px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-100" />
                <select value={type} onChange={e => setType(e.target.value as any)} className="px-3 py-2 border border-slate-200 rounded-lg text-sm bg-white">
                  <option value="all">Všetky</option>
                  <option value="system">Systémový dodávateľ</option>
                  <option value="firm">Firmy</option>
                </select>
              </div>
              <div className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">
                <table className="w-full text-sm">
                  <thead><tr className="text-left text-xs text-slate-500 uppercase border-b"><th className="px-5 py-3">Produkt</th><th className="px-5 py-3">Predajca</th><th className="px-5 py-3 text-right">Cena</th><th className="px-5 py-3 text-right">Množstvo</th><th></th></tr></thead>
                  <tbody>
                    {filtered.map(p => (
                      <tr key={p.id} className="border-b border-slate-50 last:border-0 hover:bg-slate-50/60">
                        <td className="px-5 py-3 font-medium">{p.name}</td>
                        <td className="px-5 py-3"><span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${p.type === 'system' ? 'bg-indigo-50 text-indigo-700' : 'bg-emerald-50 text-emerald-700'}`}>{p.seller}</span></td>
                        <td className="px-5 py-3 text-right font-medium">{formatEur(p.price)}</td>
                        <td className="px-5 py-3 text-right text-slate-600">{p.quantity} ks</td>
                        <td className="px-5 py-3 text-right"><button className="text-sm font-medium text-blue-600 hover:text-blue-800">Kúpiť</button></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {filtered.length === 0 && <div className="px-5 py-8 text-center text-sm text-slate-400">Žiadne výsledky.</div>}
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

function Kpi({ title, value, hint }: { title: string; value: string; hint: string }) {
  return (
    <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
      <div className="text-xs font-medium text-slate-500 uppercase tracking-wide">{title}</div>
      <div className="mt-2 text-2xl font-semibold">{value}</div>
      <div className="mt-1 text-xs text-slate-400">{hint}</div>
    </div>
  );
}

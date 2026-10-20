'use client';

import { useEffect, useState, useRef } from 'react';
import { supabase } from '../lib/supabase';

function formatEur(n: number) {
  return n.toLocaleString('sk-SK', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
}

export default function App() {
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState(false);

  const [tab, setTab] = useState<'dashboard' | 'market' | 'classes'>('classes');
  const [profileOpen, setProfileOpen] = useState(false);
  const [notifOpen, setNotifOpen] = useState(false);
  const profileRef = useRef<HTMLDivElement>(null);
  const notifRef = useRef<HTMLDivElement>(null);

  const [classes, setClasses] = useState<any[]>([]);
  const [selectedClass, setSelectedClass] = useState('');
  const [className, setClassName] = useState('');
  const [joinCode, setJoinCode] = useState('');
  const [products, setProducts] = useState<any[]>([]);
  const [firms, setFirms] = useState<any[]>([]);
  const [listings, setListings] = useState<any[]>([]);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      setUser(data.user);
      setLoading(false);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, session) => {
      setUser(session?.user ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (user) loadClasses();
  }, [user]);

  useEffect(() => {
    if (selectedClass) {
      loadProducts();
      loadFirms();
      loadListings();
    }
  }, [selectedClass]);

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (profileRef.current && !profileRef.current.contains(e.target as Node)) setProfileOpen(false);
      if (notifRef.current && !notifRef.current.contains(e.target as Node)) setNotifOpen(false);
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  function show(m: string, isErr = false) { setMsg(m); setErr(isErr); }

  async function signIn() {
    setErr(false);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) { show(error.message, true); return; }
    show('Prihlásený');
  }
  async function signUp() {
    setErr(false);
    const { error } = await supabase.auth.signUp({ email, password });
    if (error) show(error.message, true);
    else show('Registrácia odoslaná. Skontroluj e-mail.');
  }
  async function signOut() {
    await supabase.auth.signOut();
    setUser(null);
    setClasses([]);
    setSelectedClass('');
  }

  async function loadClasses() {
    const { data, error } = await supabase.from('classes').select('id,name,join_code,simulation_status');
    if (!error) setClasses(data || []);
  }
  async function createClass() {
    const { data, error } = await supabase.rpc('create_class', { p_name: className });
    if (error) show(error.message, true);
    else { show('Trieda vytvorená'); setClassName(''); loadClasses(); }
  }
  async function joinClass() {
    const { error } = await supabase.rpc('join_class', { p_code: joinCode });
    if (error) show(error.message, true);
    else { show('Pripojený'); setJoinCode(''); loadClasses(); }
  }
  async function setStatus(s: string) {
    if (!selectedClass) return;
    const { error } = await supabase.rpc('set_class_status', { p_class_id: selectedClass, p_status: s });
    if (error) show(error.message, true);
    else { show(`Stav: ${s}`); loadClasses(); }
  }

  async function loadProducts() {
    const { data } = await supabase.from('products').select('id,name').eq('class_id', selectedClass);
    setProducts(data || []);
  }
  async function loadFirms() {
    const { data } = await supabase.from('firms').select('id,name,cash_balance,status').eq('class_id', selectedClass);
    setFirms(data || []);
  }
  async function loadListings() {
    const { data } = await supabase.from('listings').select('id,product_id,quantity_available,unit_price,seller_type,products(name)').eq('status', 'active');
    setListings(data || []);
  }

  if (loading) return <div className="min-h-screen flex items-center justify-center bg-slate-50">Načítavam…</div>;

  if (!user) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#0c1222]">
        <div className="bg-white p-8 rounded-xl w-full max-w-sm shadow-xl">
          <h1 className="text-2xl font-semibold mb-1">SimuCorp</h1>
          <p className="text-sm text-slate-500 mb-6">Prihlásenie</p>
          <input className="w-full mb-3 px-3 py-2 border rounded-lg text-sm" placeholder="E-mail" value={email} onChange={e => setEmail(e.target.value)} />
          <input className="w-full mb-4 px-3 py-2 border rounded-lg text-sm" type="password" placeholder="Heslo" value={password} onChange={e => setPassword(e.target.value)} />
          <div className="flex gap-2">
            <button onClick={signIn} className="flex-1 bg-blue-600 text-white py-2 rounded-lg text-sm font-medium">Prihlásiť</button>
            <button onClick={signUp} className="flex-1 border py-2 rounded-lg text-sm">Registrovať</button>
          </div>
          {msg && <div className={`mt-4 text-sm p-3 rounded ${err ? 'bg-red-50 text-red-700' : 'bg-green-50 text-green-700'}`}>{msg}</div>}
        </div>
      </div>
    );
  }

  const title = tab === 'dashboard' ? 'Prehľad' : tab === 'market' ? 'Trh' : 'Triedy';

  return (
    <div className="flex min-h-screen bg-slate-50">
      <aside className="w-64 bg-[#0c1222] text-slate-300 flex flex-col min-h-screen shrink-0">
        <div className="px-5 py-5 flex items-center gap-2.5">
          <div className="w-7 h-7 rounded-md bg-blue-600 flex items-center justify-center text-white text-xs font-bold">S</div>
          <span className="font-semibold text-white">SimuCorp</span>
        </div>
        <nav className="flex-1 px-3 py-2 space-y-0.5">
          <button onClick={() => setTab('classes')} className={`w-full text-left px-3 py-2 rounded-lg text-sm ${tab === 'classes' ? 'bg-slate-800 text-white' : 'hover:bg-slate-800/60'}`}>Triedy</button>
          <button onClick={() => setTab('dashboard')} className={`w-full text-left px-3 py-2 rounded-lg text-sm ${tab === 'dashboard' ? 'bg-slate-800 text-white' : 'hover:bg-slate-800/60'}`}>Prehľad</button>
          <button onClick={() => setTab('market')} className={`w-full text-left px-3 py-2 rounded-lg text-sm ${tab === 'market' ? 'bg-slate-800 text-white' : 'hover:bg-slate-800/60'}`}>Trh</button>
        </nav>
        <div className="px-4 py-3 text-xs text-slate-500 border-t border-slate-800">{user.email}</div>
      </aside>

      <div className="flex-1 flex flex-col min-w-0">
        <header className="h-14 bg-[#0c1222] border-b border-slate-800/60 flex items-center justify-between px-6">
          <h1 className="text-white font-medium">{title}</h1>
          <div className="flex items-center gap-3">
            <div className="relative" ref={notifRef}>
              <button onClick={() => { setNotifOpen(!notifOpen); setProfileOpen(false); }} className="p-1.5 text-slate-400 hover:text-slate-200 relative">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
                <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full" />
              </button>
              {notifOpen && <div className="absolute right-0 top-full mt-2 w-64 bg-white rounded-lg shadow-lg border p-3 text-sm text-slate-600 z-50">Žiadne notifikácie</div>}
            </div>
            <div className="relative" ref={profileRef}>
              <button onClick={() => { setProfileOpen(!profileOpen); setNotifOpen(false); }} className="flex items-center gap-2 text-slate-400 hover:text-slate-200">
                <div className="w-7 h-7 rounded-full bg-slate-700 text-white text-xs flex items-center justify-center">{user.email?.[0]?.toUpperCase()}</div>
                <span className="text-sm hidden sm:inline">Profil</span>
              </button>
              {profileOpen && (
                <div className="absolute right-0 top-full mt-2 w-44 bg-white rounded-lg shadow-lg border py-1 z-50">
                  <button onClick={signOut} className="w-full text-left px-4 py-2 text-sm text-rose-600 hover:bg-rose-50">Odhlásiť sa</button>
                </div>
              )}
            </div>
          </div>
        </header>

        <main className="flex-1 p-6 lg:p-8 overflow-auto">
          {tab === 'classes' && (
            <div className="space-y-6 max-w-2xl">
              <div className="bg-white border rounded-xl p-5 shadow-sm">
                <h2 className="text-sm font-medium mb-3">Nová trieda</h2>
                <div className="flex gap-2">
                  <input value={className} onChange={e => setClassName(e.target.value)} placeholder="Názov triedy" className="flex-1 px-3 py-2 border rounded-lg text-sm" />
                  <button onClick={createClass} className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm">Vytvoriť</button>
                </div>
              </div>
              <div className="bg-white border rounded-xl p-5 shadow-sm">
                <h2 className="text-sm font-medium mb-3">Vstúpiť cez kód</h2>
                <div className="flex gap-2">
                  <input value={joinCode} onChange={e => setJoinCode(e.target.value)} placeholder="Kód" className="flex-1 px-3 py-2 border rounded-lg text-sm" />
                  <button onClick={joinClass} className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm">Vstúpiť</button>
                </div>
              </div>
              <div className="bg-white border rounded-xl p-5 shadow-sm">
                <h2 className="text-sm font-medium mb-3">Moje triedy</h2>
                <select value={selectedClass} onChange={e => setSelectedClass(e.target.value)} className="w-full px-3 py-2 border rounded-lg text-sm mb-3">
                  <option value="">— vyber triedu —</option>
                  {classes.map(c => <option key={c.id} value={c.id}>{c.name} ({c.join_code}) [{c.simulation_status}]</option>)}
                </select>
                {selectedClass && (
                  <div className="flex gap-2">
                    <button onClick={() => setStatus('running')} className="text-sm border px-3 py-1.5 rounded">Spustiť</button>
                    <button onClick={() => setStatus('paused')} className="text-sm border px-3 py-1.5 rounded">Pozastaviť</button>
                    <button onClick={() => setStatus('archived')} className="text-sm border px-3 py-1.5 rounded">Archivovať</button>
                  </div>
                )}
                {classes.length === 0 && <p className="text-sm text-slate-400">Žiadne triedy.</p>}
              </div>
            </div>
          )}

          {tab === 'dashboard' && (
            <div className="space-y-6">
              <p className="text-sm text-slate-500">{selectedClass ? 'Vybraná trieda' : 'Vyber triedu v záložke Triedy'}</p>
              {selectedClass && firms.length > 0 && (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                  <div className="bg-white border rounded-xl p-5 shadow-sm">
                    <div className="text-xs text-slate-500 uppercase">Hotovosť</div>
                    <div className="text-2xl font-semibold mt-1">{formatEur(firms[0]?.cash_balance || 0)}</div>
                  </div>
                </div>
              )}
            </div>
          )}

          {tab === 'market' && selectedClass && (
            <div className="bg-white border rounded-xl shadow-sm overflow-hidden">
              <table className="w-full text-sm">
                <thead><tr className="text-left text-xs text-slate-500 uppercase border-b"><th className="px-5 py-3">Produkt</th><th className="px-5 py-3 text-right">Cena</th><th className="px-5 py-3 text-right">Množstvo</th><th className="px-5 py-3">Typ</th></tr></thead>
                <tbody>
                  {listings.map(l => (
                    <tr key={l.id} className="border-b last:border-0">
                      <td className="px-5 py-3">{l.products?.name || '—'}</td>
                      <td className="px-5 py-3 text-right">{l.unit_price}</td>
                      <td className="px-5 py-3 text-right">{l.quantity_available}</td>
                      <td className="px-5 py-3">{l.seller_type}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {listings.length === 0 && <div className="p-5 text-sm text-slate-400">Žiadne ponuky.</div>}
            </div>
          )}

          {msg && <div className={`mt-4 text-sm p-3 rounded ${err ? 'bg-red-50 text-red-700' : 'bg-green-50 text-green-700'}`}>{msg}</div>}
        </main>
      </div>
    </div>
  );
}

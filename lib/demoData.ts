export const kpis = {
  cash: 12450.75,
  revenue: 8320.40,
  inventoryValue: 4150.20,
  trades: 27,
};

export const cashFlow = [
  { month: 'Jan', value: 8200 },
  { month: 'Feb', value: 9100 },
  { month: 'Mar', value: 8800 },
  { month: 'Apr', value: 10200 },
  { month: 'Máj', value: 11500 },
  { month: 'Jún', value: 10900 },
  { month: 'Júl', value: 12100 },
  { month: 'Aug', value: 11800 },
  { month: 'Sep', value: 12450 },
];

export const transactions = [
  { id: '1', date: '18. 10. 2026', description: 'Predaj – Pero A4', category: 'Tržby', amount: 245.00 },
  { id: '2', date: '17. 10. 2026', description: 'Nákup od systému – Papier', category: 'Nákup', amount: -180.50 },
  { id: '3', date: '16. 10. 2026', description: 'Predaj – Zošit', category: 'Tržby', amount: 96.00 },
  { id: '4', date: '15. 10. 2026', description: 'Nákup – Fixy', category: 'Nákup', amount: -42.30 },
  { id: '5', date: '14. 10. 2026', description: 'Predaj – Blok', category: 'Tržby', amount: 128.00 },
];

export const products = [
  { id: 'p1', name: 'Pero guličkové', price: 0.85, quantity: 120, seller: 'Systémový dodávateľ', type: 'system' },
  { id: 'p2', name: 'Zošit A5', price: 1.20, quantity: 85, seller: 'Firma Alfa', type: 'firm' },
  { id: 'p3', name: 'Papier A4 (500 ks)', price: 4.50, quantity: 40, seller: 'Systémový dodávateľ', type: 'system' },
  { id: 'p4', name: 'Fixy sada', price: 3.10, quantity: 30, seller: 'Firma Beta', type: 'firm' },
  { id: 'p5', name: 'Blok poznámkový', price: 2.40, quantity: 55, seller: 'Firma Alfa', type: 'firm' },
  { id: 'p6', name: 'Lepiaca páska', price: 1.15, quantity: 70, seller: 'Systémový dodávateľ', type: 'system' },
];

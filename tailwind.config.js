/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{js,ts,jsx,tsx}', './components/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        navy: {
          900: '#0b1220',
          800: '#111827',
          700: '#1e293b',
        },
        royal: '#1d4ed8',
      },
    },
  },
  plugins: [],
};

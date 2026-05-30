/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,ts}'],
  theme: {
    extend: {
      colors: {
        accent: '#E8442A',        // reticle red
        'accent-dim': '#B03320',
        surface: '#111114',
        'surface-raised': '#18181C',
        'surface-border': '#2A2A30',
        'text-primary': '#F0F0F2',
        'text-secondary': '#8A8A96',
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Display', 'Segoe UI', 'sans-serif'],
        mono: ['SF Mono', 'JetBrains Mono', 'Fira Code', 'monospace'],
      },
    },
  },
};

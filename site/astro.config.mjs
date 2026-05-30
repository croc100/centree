import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  integrations: [tailwind()],
  site: 'https://croc100.github.io',
  base: '/Reticle',
  output: 'static',
  trailingSlash: 'always',
});

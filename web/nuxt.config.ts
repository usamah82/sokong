// https://nuxt.com/docs/4.x/api/nuxt-config
// https://nuxt.com/docs/4.x/getting-started/upgrade#new-directory-structure
// https://i18n.nuxtjs.org/docs/api/options
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  srcDir: '.',
  css: [ '~/assets/sokong.css' ],
  devServer: {
    port: 3001
  },
  runtimeConfig: {
    public: {
      apiBase: 'http://localhost:3000'
    }
  },
  modules: [ '@nuxtjs/i18n', '@nuxt/eslint' ],
  i18n: {
    defaultLocale: 'en',
    strategy: 'no_prefix',
    locales: [
      { code: 'en', language: 'en', file: 'en.json' }
    ],
    langDir: 'locales'
  }
})

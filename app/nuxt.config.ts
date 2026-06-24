// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: [
    '@nuxt/eslint',
    '@nuxt/ui',
    '@nuxtjs/supabase'
  ],

  supabase: {
    url: process.env.SUPABASE_URL ?? 'https://eccermneumcskamtitqh.supabase.co',
    key: process.env.SUPABASE_KEY ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjY2VybW5ldW1jc2thbXRpdHFoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMzE0NzUsImV4cCI6MjA5NzcwNzQ3NX0.rXXQ7tRf7u7qqhZL1cxea4CJEljnwAX2cNPrhNdYR2A',
    redirectOptions: {
      login: '/login',
      callback: '/confirm',
      exclude: ['/', '/login', '/confirm', '/forgot-password', '/register']
    }
  },

  runtimeConfig: {
    groqApiKey: process.env.GROQ_API_KEY ?? '',
    supabaseServiceKey: process.env.SUPABASE_SERVICE_KEY ?? '',
    public: {
      supabaseUrl: process.env.SUPABASE_URL ?? 'https://eccermneumcskamtitqh.supabase.co',
    },
  },

  icon: {
    serverBundle: {
      collections: ['lucide']
    }
  },

  colorMode: {
    preference: 'light',
    fallback: 'light'
  },

  devtools: {
    enabled: true
  },

  css: ['~/assets/css/main.css'],

  routeRules: {},

  compatibilityDate: '2025-01-15',

  eslint: {
    config: {
      stylistic: {
        commaDangle: 'never',
        braceStyle: '1tbs'
      }
    }
  }
})

export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const { kpiData, trends, forecast, riskScores, demandData } = body

  const apiKey = process.env.GROQ_API_KEY || useRuntimeConfig().groqApiKey
  if (!apiKey) {
    return { insight: 'API Key Groq belum dikonfigurasi. Set GROQ_API_KEY di environment variables.', model: 'none' }
  }

  const systemPrompt = `Kamu adalah AI analis keuangan & supply chain untuk KSM (Koperasi Supply Management) di industri logistik rumah sakit Indonesia.

Konteks bisnis:
- KSM adalah intermediary antara RS (Rumah Sakit), Distributor farmasi, dan Bank
- Bank bayar Distributor atas nama KSM (SCF/Reverse Factoring)
- RS bayar KSM setelah BPJS cair via Standing Instruction bank custodian
- Jika RS kekurangan dana, Bank cover shortfall dengan bunga harian 50% KSM / 50% RS
- SCF dijamin oleh RS selaku end user

Tugas: Berikan analisis mendalam dan actionable dalam Bahasa Indonesia. Format:
1. RINGKASAN EKSEKUTIF (2-3 kalimat)
2. TEMUAN KRITIS (maks 3 poin, dengan angka spesifik)
3. PREDIKSI (berdasarkan trend data)
4. REKOMENDASI AKSI (3 langkah prioritas)

Gunakan angka spesifik dari data. Jangan generalisasi. Fokus pada risiko dan peluang.`

  const userPrompt = `Analisis data KSM berikut:

KPI Dashboard:
${JSON.stringify(kpiData, null, 2)}

Trend Bulanan (6 bulan):
${JSON.stringify(trends, null, 2)}

Forecast 3 Bulan:
${JSON.stringify(forecast, null, 2)}

Risk Score per RS:
${JSON.stringify(riskScores, null, 2)}

Demand Analysis (top items):
${JSON.stringify(demandData?.slice(0, 10), null, 2)}

Berikan analisis lengkap.`

  try {
    const response = await $fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: {
        model: 'llama-3.3-70b-versatile',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.3,
        max_tokens: 2000,
      },
    })

    const msg = (response as any).choices?.[0]?.message?.content ?? 'Tidak ada respons dari AI'
    return {
      insight: msg,
      model: 'llama-3.3-70b-versatile',
      provider: 'groq',
      tokens: (response as any).usage?.total_tokens ?? 0,
    }
  } catch (e: any) {
    return {
      insight: `Error dari Groq API: ${e.message ?? 'Unknown error'}`,
      model: 'error',
      error: true,
    }
  }
})

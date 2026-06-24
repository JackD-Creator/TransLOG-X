package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

type insightReq struct {
	KPIData    any `json:"kpiData"`
	Trends     any `json:"trends"`
	Forecast   any `json:"forecast"`
	RiskScores any `json:"riskScores"`
	DemandData any `json:"demandData"`
}

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

	if r.Method == "OPTIONS" { w.WriteHeader(204); return }
	if r.Method != "POST" { http.Error(w, `{"error":"method not allowed"}`, 405); return }

	apiKey := os.Getenv("GROQ_API_KEY")
	if apiKey == "" {
		json.NewEncoder(w).Encode(map[string]any{"insight": "GROQ_API_KEY belum dikonfigurasi.", "model": "none"})
		return
	}

	var req insightReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, 400); return
	}

	kpiJSON, _ := json.MarshalIndent(req.KPIData, "", "  ")
	trendsJSON, _ := json.MarshalIndent(req.Trends, "", "  ")
	forecastJSON, _ := json.MarshalIndent(req.Forecast, "", "  ")
	riskJSON, _ := json.MarshalIndent(req.RiskScores, "", "  ")
	demandJSON, _ := json.MarshalIndent(req.DemandData, "", "  ")

	systemPrompt := `Kamu adalah AI analis keuangan & supply chain untuk KSM (Koperasi Supply Management) di industri logistik rumah sakit Indonesia.

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

	userPrompt := fmt.Sprintf(`Analisis data KSM berikut:

KPI Dashboard:
%s

Trend Bulanan (6 bulan):
%s

Forecast 3 Bulan:
%s

Risk Score per RS:
%s

Demand Analysis (top items):
%s

Berikan analisis lengkap.`, string(kpiJSON), string(trendsJSON), string(forecastJSON), string(riskJSON), string(demandJSON))

	groqBody := map[string]any{
		"model": "llama-3.3-70b-versatile",
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": userPrompt},
		},
		"temperature": 0.3,
		"max_tokens":  2000,
	}

	b, _ := json.Marshal(groqBody)
	groqReq, _ := http.NewRequest("POST", "https://api.groq.com/openai/v1/chat/completions", bytes.NewReader(b))
	groqReq.Header.Set("Content-Type", "application/json")
	groqReq.Header.Set("Authorization", "Bearer "+apiKey)

	resp, err := http.DefaultClient.Do(groqReq)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]any{"insight": "Error: " + err.Error(), "error": true})
		return
	}
	defer resp.Body.Close()
	rb, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != 200 {
		json.NewEncoder(w).Encode(map[string]any{"insight": fmt.Sprintf("Groq API error %d: %s", resp.StatusCode, string(rb)), "error": true})
		return
	}

	var gr struct {
		Choices []struct {
			Message struct{ Content string `json:"content"` } `json:"message"`
		} `json:"choices"`
		Usage struct{ TotalTokens int `json:"total_tokens"` } `json:"usage"`
	}
	json.Unmarshal(rb, &gr)

	insight := "Tidak ada respons dari AI"
	if len(gr.Choices) > 0 {
		insight = gr.Choices[0].Message.Content
	}

	json.NewEncoder(w).Encode(map[string]any{
		"insight":  insight,
		"model":    "llama-3.3-70b-versatile",
		"provider": "groq",
		"tokens":   gr.Usage.TotalTokens,
	})
}

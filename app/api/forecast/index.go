package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

type forecastItem struct {
	Name     string  `json:"name"`
	Stock    int     `json:"stock"`
	AvgDaily float64 `json:"avg_daily"`
	Category string  `json:"category"`
}

type forecastReq struct {
	Items []forecastItem `json:"items"`
}

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(204)
		return
	}
	if r.Method != "POST" {
		http.Error(w, `{"error":"method not allowed"}`, 405)
		return
	}

	var req forecastReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, 400)
		return
	}

	if len(req.Items) == 0 {
		json.NewEncoder(w).Encode(map[string]any{"predictions": []any{}, "summary": "Tidak ada data."})
		return
	}

	var lines []string
	for _, i := range req.Items {
		lines = append(lines, fmt.Sprintf("- %s: stok %d, avg %.1f /hari, kategori %s", i.Name, i.Stock, i.AvgDaily, i.Category))
	}

	prompt := fmt.Sprintf(`Kamu adalah AI logistik rumah sakit Indonesia. Analisis data inventory berikut dan buat prediksi demand 30 hari ke depan.

Data inventory:
%s

Response JSON:
{
  "predictions": [
    {"name":"nama item","predicted_demand_30d":angka,"reorder_point":angka,"reorder_qty":angka,"confidence":0.0-1.0,"risk":"low|medium|high","note":"catatan singkat"}
  ],
  "summary": "ringkasan 1-2 kalimat"
}`, strings.Join(lines, "\n"))

	result, err := callGroq(
		[]groqMsg{
			{Role: "system", Content: "Kamu adalah AI supply chain analyst untuk rumah sakit. Jawab dalam JSON valid."},
			{Role: "user", Content: prompt},
		}, 0.3, 2048, true)

	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), 500)
		return
	}
	w.Write([]byte(result))
}

type groqMsg struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

func callGroq(messages []groqMsg, temp float64, maxTok int, jsonMode bool) (string, error) {
	apiKey := os.Getenv("GROQ_API_KEY")
	if apiKey == "" {
		return "", fmt.Errorf("GROQ_API_KEY not set")
	}
	body := map[string]any{
		"model": "llama-3.3-70b-versatile", "messages": messages,
		"temperature": temp, "max_tokens": maxTok,
	}
	if jsonMode {
		body["response_format"] = map[string]string{"type": "json_object"}
	}
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", "https://api.groq.com/openai/v1/chat/completions", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	rb, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("groq %d: %s", resp.StatusCode, string(rb))
	}
	var gr struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	json.Unmarshal(rb, &gr)
	if len(gr.Choices) == 0 {
		return "{}", nil
	}
	return gr.Choices[0].Message.Content, nil
}

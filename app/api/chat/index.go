package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

type chatReq struct {
	Question string `json:"question"`
	Context  string `json:"context"`
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

	var req chatReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, 400)
		return
	}

	if req.Question == "" {
		http.Error(w, `{"error":"question required"}`, 400)
		return
	}

	systemPrompt := fmt.Sprintf(`Kamu adalah asisten AI untuk platform logistik rumah sakit TransLOG-X. Jawab pertanyaan user tentang inventory, pengadaan, keuangan, BPJS, dan supply chain. Jawab dalam Bahasa Indonesia, singkat dan actionable.

Konteks data saat ini:
%s`, req.Context)

	result, err := callGroq(
		[]groqMsg{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: req.Question},
		}, 0.5, 1024, false)

	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), 500)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"answer": result})
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
		return "", nil
	}
	return gr.Choices[0].Message.Content, nil
}

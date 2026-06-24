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

type bpjsReq struct {
	InvoiceID string  `json:"invoice_id"`
	Amount    float64 `json:"amount"`
	Date      string  `json:"date"`
}

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	if r.Method == "OPTIONS" { w.WriteHeader(204); return }
	if r.Method != "POST" { jsonErr(w, "method not allowed", 405); return }

	user, err := verifyAuth(r)
	if err != nil { jsonErr(w, err.Error(), 401); return }
	_ = user

	var req bpjsReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonErr(w, "invalid json", 400); return
	}
	if req.InvoiceID == "" { jsonErr(w, "invoice_id required", 400); return }

	params := map[string]any{"p_invoice_id": req.InvoiceID, "p_bpjs_amount": req.Amount}
	if req.Date != "" {
		params["p_bpjs_date"] = req.Date
	}

	data, err := rpc("process_bpjs_payment", params)
	if err != nil { jsonErr(w, err.Error(), 400); return }
	json.NewEncoder(w).Encode(json.RawMessage(data))
}

// --- inline helpers (standalone for Vercel) ---

type authUser struct{ tenantID, tenantType string }

func verifyAuth(r *http.Request) (*authUser, error) {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") { return nil, fmt.Errorf("unauthorized") }
	req, _ := http.NewRequest("GET", sbURL()+"/auth/v1/user", nil)
	req.Header.Set("Authorization", auth)
	req.Header.Set("apikey", sbKey())
	resp, err := http.DefaultClient.Do(req)
	if err != nil { return nil, err }
	defer resp.Body.Close()
	if resp.StatusCode != 200 { return nil, fmt.Errorf("invalid token") }
	var u struct{ AppMeta map[string]any `json:"app_metadata"` }
	json.NewDecoder(resp.Body).Decode(&u)
	tid, _ := u.AppMeta["tenant_id"].(string)
	tt, _ := u.AppMeta["tenant_type"].(string)
	if tid == "" { return nil, fmt.Errorf("no tenant") }
	return &authUser{tid, tt}, nil
}

func rpc(name string, params any) (json.RawMessage, error) {
	b, _ := json.Marshal(params)
	req, _ := http.NewRequest("POST", sbURL()+"/rest/v1/rpc/"+name, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apikey", sbKey())
	req.Header.Set("Authorization", "Bearer "+sbKey())
	resp, err := http.DefaultClient.Do(req)
	if err != nil { return nil, err }
	defer resp.Body.Close()
	rb, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 { return nil, fmt.Errorf("%s", rb) }
	return rb, nil
}

func sbURL() string { if v := os.Getenv("SUPABASE_URL"); v != "" { return v }; return "https://eccermneumcskamtitqh.supabase.co" }
func sbKey() string { return os.Getenv("SUPABASE_SERVICE_KEY") }
func jsonErr(w http.ResponseWriter, msg string, code int) { w.WriteHeader(code); json.NewEncoder(w).Encode(map[string]string{"error": msg}) }

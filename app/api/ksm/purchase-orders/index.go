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

type poReq struct {
	Action        string          `json:"action"`
	POID          string          `json:"po_id"`
	Status        string          `json:"status"`
	Reason        string          `json:"reason"`
	ReceivedItems json.RawMessage `json:"received_items"`
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

	var req poReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonErr(w, "invalid json", 400); return
	}
	if req.POID == "" { jsonErr(w, "po_id required", 400); return }

	switch req.Action {
	case "approve":
		data, err := rpc("ksm_approve_po", map[string]string{"p_po_id": req.POID})
		if err != nil { jsonErr(w, err.Error(), 400); return }
		json.NewEncoder(w).Encode(json.RawMessage(data))

	case "request_correction":
		data, err := rpc("ksm_request_po_correction", map[string]any{"p_po_id": req.POID, "p_reason": req.Reason})
		if err != nil { jsonErr(w, err.Error(), 400); return }
		json.NewEncoder(w).Encode(json.RawMessage(data))

	case "confirm_receipt":
		data, err := rpc("rs_confirm_receipt", map[string]any{"p_po_id": req.POID, "p_received_items": req.ReceivedItems})
		if err != nil { jsonErr(w, err.Error(), 400); return }
		json.NewEncoder(w).Encode(json.RawMessage(data))

	case "update_status":
		if req.Status == "" { jsonErr(w, "status required", 400); return }
		_, err := mutate("PATCH", "ksm_purchase_orders", "id=eq."+req.POID, map[string]string{"status": req.Status})
		if err != nil { jsonErr(w, err.Error(), 400); return }
		json.NewEncoder(w).Encode(map[string]bool{"success": true})

	default:
		jsonErr(w, "unknown action: "+req.Action, 400)
	}
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

func mutate(method, table, filter string, body any) ([]byte, error) {
	var br io.Reader
	if body != nil { b, _ := json.Marshal(body); br = bytes.NewReader(b) }
	req, _ := http.NewRequest(method, sbURL()+"/rest/v1/"+table+"?"+filter, br)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apikey", sbKey())
	req.Header.Set("Authorization", "Bearer "+sbKey())
	req.Header.Set("Prefer", "return=minimal")
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

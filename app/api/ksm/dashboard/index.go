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

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	if r.Method == "OPTIONS" { w.WriteHeader(204); return }
	if r.Method != "GET" { jsonErr(w, "method not allowed", 405); return }

	user, err := verifyAuth(r)
	if err != nil { jsonErr(w, err.Error(), 401); return }

	kpi, _ := rpc("get_ksm_dashboard_kpi", map[string]string{"p_ksm_tenant_id": user.tenantID})
	trends, _ := rpc("get_monthly_trends", map[string]any{"p_ksm_tenant_id": user.tenantID, "p_months": 6})
	forecast, _ := rpc("forecast_next_months", map[string]any{"p_ksm_tenant_id": user.tenantID, "p_forecast_months": 3})
	risk, _ := rpc("get_rs_risk_scores", map[string]string{"p_ksm_tenant_id": user.tenantID})
	demand, _ := rpc("get_demand_analysis", map[string]string{"p_ksm_tenant_id": user.tenantID})

	json.NewEncoder(w).Encode(map[string]any{
		"kpi": kpi, "trends": trends, "forecast": forecast,
		"risk_scores": risk, "demand_data": demand,
	})
}

type authUser struct { tenantID, tenantType string }

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
	var u struct { AppMeta map[string]any `json:"app_metadata"` }
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

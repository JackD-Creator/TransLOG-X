package handler

import (
	"encoding/json"
	"net/http"
	"time"
)

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(map[string]any{
		"status":  "ok",
		"service": "translog-x-api",
		"version": "1.0.0",
		"time":    time.Now().Format(time.RFC3339),
	})
}

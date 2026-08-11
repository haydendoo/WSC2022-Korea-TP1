package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"
)

// Server holds the dependency needed to answer requests: the DynamoDB
// client. This is a practice stand-in for the real "server-stub" binary
// described in the Day 1 spec, not a reproduction of it.
type Server struct {
	cfg *Config
	db  *DB
}

func NewServer(cfg *Config, db *DB) *Server {
	return &Server{cfg: cfg, db: db}
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", s.handleHealth)
	mux.HandleFunc("GET /healthz", s.handleHealth)
	mux.HandleFunc("GET /unicorn/{id}", s.handleGetUnicorn)
	return mux
}

// handleHealth is the documented health check: once GameDay gets an HTTP
// 200 response from the root path, it attests that the application is
// running normally (mirrors the Day 2 binaries' behaviour, which the Day
// 1 spec's "reachable" scoring criterion implies as well).
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"service": "server",
		"status":  "ok",
	})
}

// handleGetUnicorn is the "result searching request" the spec describes
// (Gentle reminder #2): "result searching request will be sent to your
// web service to fetch out the data in your DynamoDB table". It queries
// the unicorn table by partition key id and returns every sentiment
// analysis result recorded for that id.
func (s *Server) handleGetUnicorn(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	records, err := s.db.QueryByID(ctx, id)
	if err != nil {
		log.Printf("warn: dynamodb query failed for id=%q: %v", id, err)
		http.Error(w, `{"error":"could not query DynamoDB"}`, http.StatusServiceUnavailable)
		return
	}

	if len(records) == 0 {
		http.Error(w, `{"error":"no record found for this id"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(records)
}

// Atom Browser UI prototype: standard-library-only search API and static website.
// This is NOT a production materials registry or an authentication service.
package main

import (
	"compress/gzip"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

//go:embed static/*
var assets embed.FS

type Material struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Type        string `json:"type"`
	Description string `json:"description"`
}

type SearchResponse struct {
	Query       string     `json:"query"`
	Page        int        `json:"page"`
	PageSize    int        `json:"page_size"`
	Total       int        `json:"total"`
	TotalPages  int        `json:"total_pages"`
	Items       []Material `json:"items"`
	Suggestions []string   `json:"suggestions"`
}

var titles = []struct{ name, category string }{
	{"Титановый сплав ВТ6", "Сплав"},
	{"Титановый сплав ВТ1-0", "Сплав"},
	{"Диоксид титана (TiO₂)", "Вещество"},
	{"Нитрид титана (TiN)", "Вещество"},
	{"Карбид титана (TiC)", "Вещество"},
	{"Никелевый сплав", "Сплав"},
	{"Медный сплав", "Сплав"},
	{"Нержавеющая сталь", "Сплав"},
	{"Оксид алюминия (Al₂O₃)", "Вещество"},
	{"Кремний высокой чистоты", "Материал"},
	{"Кобальтовый сплав", "Сплав"},
	{"Вольфрамовый карбид", "Вещество"},
}

func dataset() []Material {
	results := make([]Material, 0, 144)
	for n := 0; n < 12; n++ {
		for i, t := range titles {
			label := t.name
			if n > 0 {
				label = fmt.Sprintf("%s — образец %02d", label, n+1)
			}
			results = append(results, Material{
				ID:          fmt.Sprintf("DEMO-%04d", n*len(titles)+i+1),
				Name:        label,
				Type:        t.category,
				Description: "Демонстрационная карточка: не является записью официального реестра веществ или материалов.",
			})
		}
	}
	return results
}

var materials = dataset()

func paramInt(r *http.Request, name string, def, min, max int) int {
	n, err := strconv.Atoi(r.URL.Query().Get(name))
	if err != nil {
		return def
	}
	if n < min {
		return min
	}
	if n > max {
		return max
	}
	return n
}

func matches(haystack, needle string) bool {
	return strings.Contains(strings.ToLower(haystack), strings.ToLower(needle))
}

func suggestions(q string, matchesList []Material) []string {
	result := []string{}
	seen := map[string]bool{}
	if q == "" {
		return result
	}
	for _, m := range matchesList {
		base := strings.Split(m.Name, " — образец")[0]
		if !seen[base] && len(result) < 5 {
			seen[base] = true
			result = append(result, base)
		}
	}
	return result
}

func gzipAccepted(accept string) bool {
	for _, token := range strings.Split(strings.ToLower(accept), ",") {
		bits := strings.Split(strings.TrimSpace(token), ";")
		if len(bits) == 0 || strings.TrimSpace(bits[0]) != "gzip" {
			continue
		}
		ok := true
		for _, p := range bits[1:] {
			p = strings.ReplaceAll(strings.TrimSpace(p), " ", "")
			if strings.HasPrefix(p, "q=") {
				value, err := strconv.ParseFloat(strings.TrimPrefix(p, "q="), 64)
				if err != nil || value <= 0 {
					ok = false
				}
			}
		}
		return ok
	}
	return false
}

func jsonResponse(w http.ResponseWriter, r *http.Request, response SearchResponse) {
	body, err := json.Marshal(response)
	if err != nil {
		http.Error(w, "encoding error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "private, no-store")
	w.Header().Set("Vary", "Accept-Encoding")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	// Small responses are cheaper to serve uncompressed.
	if len(body) >= 1024 && gzipAccepted(r.Header.Get("Accept-Encoding")) {
		w.Header().Set("Content-Encoding", "gzip")
		gz := gzip.NewWriter(w)
		defer gz.Close()
		_, _ = gz.Write(body)
		return
	}
	_, _ = w.Write(body)
}

func search(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", "GET")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	q := strings.Join(strings.Fields(strings.TrimSpace(r.URL.Query().Get("q"))), " ")
	if len([]rune(q)) > 120 {
		http.Error(w, "query is too long", http.StatusBadRequest)
		return
	}
	page := paramInt(r, "page", 1, 1, 10000)
	size := paramInt(r, "page_size", 5, 1, 25)
	filtered := make([]Material, 0, len(materials))
	for _, item := range materials {
		if q == "" || matches(item.Name, q) || matches(item.Type, q) {
			filtered = append(filtered, item)
		}
	}
	total := len(filtered)
	totalPages := (total + size - 1) / size
	if totalPages == 0 {
		totalPages = 1
	}
	if page > totalPages {
		page = totalPages
	}
	start := (page - 1) * size
	end := start + size
	if end > total {
		end = total
	}
	// Simulated API latency to make skeleton loading observable. Remove for real API.
	delay := time.NewTimer(540 * time.Millisecond)
	defer delay.Stop()
	select {
	case <-delay.C:
	case <-r.Context().Done():
		return
	}
	jsonResponse(w, r, SearchResponse{
		Query: q, Page: page, PageSize: size, Total: total,
		TotalPages: totalPages, Items: filtered[start:end], Suggestions: suggestions(q, filtered),
	})
}

func newHandler() (http.Handler, error) {
	static, err := fs.Sub(assets, "static")
	if err != nil {
		return nil, err
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/api/search", search)
	mux.Handle("/", http.FileServer(http.FS(static)))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		// Development-only local demo. Production requires a CSP tailored to deployment.
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
		mux.ServeHTTP(w, r)
	}), nil
}

func main() {
	handler, err := newHandler()
	if err != nil {
		log.Fatal(err)
	}
	addr := os.Getenv("ATOM_UI_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8765"
	}
	server := &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Printf("Atom Browser UI prototype: http://%s", server.Addr)
	err = server.ListenAndServe()
	if err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

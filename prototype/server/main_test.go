package main

import (
	"compress/gzip"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestPaginatedSearch(t *testing.T) {
	h, err := newHandler()
	if err != nil {
		t.Fatal(err)
	}
	r := httptest.NewRequest(http.MethodGet, "/api/search?q=%D1%82%D0%B8%D1%82%D0%B0%D0%BD&page=2&page_size=2", nil)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != 200 {
		t.Fatalf("HTTP %d", w.Code)
	}
	var result SearchResponse
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.Page != 2 || len(result.Items) != 2 || result.Total <= 2 {
		t.Fatalf("unexpected pagination: %+v", result)
	}
	for _, item := range result.Items {
		if !matches(item.Name, "титан") {
			t.Errorf("unexpected item: %s", item.Name)
		}
	}
}

func TestGzip(t *testing.T) {
	h, err := newHandler()
	if err != nil {
		t.Fatal(err)
	}
	r := httptest.NewRequest(http.MethodGet, "/api/search?page_size=25", nil)
	r.Header.Set("Accept-Encoding", "gzip")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Header().Get("Content-Encoding") != "gzip" {
		t.Fatalf("no compression: %v", w.Header())
	}
	gz, err := gzip.NewReader(w.Body)
	if err != nil {
		t.Fatal(err)
	}
	defer gz.Close()
	var v SearchResponse
	if err := json.NewDecoder(gz).Decode(&v); err != nil {
		t.Fatal(err)
	}
	if len(v.Items) != 25 {
		t.Fatalf("received %d", len(v.Items))
	}
}

func TestGzipDisabledQZero(t *testing.T) {
	if gzipAccepted("gzip;q=0, br") {
		t.Fatal("gzip forbidden but accepted")
	}
	if !gzipAccepted("br, gzip;q=0.7") {
		t.Fatal("gzip supported but not accepted")
	}
	if !strings.Contains("gzip", "gzip") {
		t.Fatal("unexpected")
	}
}

func TestCorporateHomepage(t *testing.T) {
	h, err := newHandler()
	if err != nil {
		t.Fatal(err)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/", nil))
	if w.Code != http.StatusOK {
		t.Fatalf("HTTP %d", w.Code)
	}
	body := w.Body.String()
	links := []string{
		"https://tel.nrcki.ru", "https://portal.nrcki.ru", "https://nrcki.ru",
		"https://next.nrcki.ru", "https://talk.nrcki.ru", "https://rp.nrcki.ru",
		"https://mail.rrcki.ru",
	}
	for _, url := range links {
		if !strings.Contains(body, `href="`+url+`"`) {
			t.Errorf("missing service: %s", url)
		}
	}
	if strings.Contains(body, `/app.js`) || strings.Contains(body, `/api/search`) {
		t.Fatal("homepage must not load or call search API")
	}
	if !strings.Contains(body, `kurchatov-emblem.png`) {
		t.Fatal("missing institute crest")
	}
}

func TestMaterialsSearchSeparatePage(t *testing.T) {
	h, err := newHandler()
	if err != nil {
		t.Fatal(err)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/materials.html", nil))
	if w.Code != http.StatusOK {
		t.Fatalf("HTTP %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), `/app.js`) {
		t.Fatal("materials search script missing from materials page")
	}
}

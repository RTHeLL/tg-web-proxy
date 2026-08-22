package server

import (
	"mime"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// staticEntry is one file of the public site, held in memory so that every
// path — statics, the index, the 404 body — is served by the exact same code
// with the exact same header set. Serving from disk on some paths and from
// memory on others is an active-probing tell, so there is only one path here.
type staticEntry struct {
	body        []byte
	contentType string
}

type staticSite struct {
	entries  map[string]*staticEntry
	index    *staticEntry
	notFound *staticEntry
	modTime  time.Time
}

func loadStaticSite(root string) (*staticSite, error) {
	site := &staticSite{entries: make(map[string]*staticEntry)}
	err := filepath.WalkDir(root, func(full string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() || !entry.Type().IsRegular() {
			return nil
		}
		relative, err := filepath.Rel(root, full)
		if err != nil {
			return err
		}
		relative = filepath.ToSlash(relative)
		if relative == "." || strings.HasPrefix(relative, "../") {
			return nil
		}
		data, err := os.ReadFile(full)
		if err != nil {
			return err
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		site.entries["/"+relative] = &staticEntry{
			body:        data,
			contentType: contentTypeFor(relative),
		}
		if info.ModTime().UTC().After(site.modTime) {
			site.modTime = info.ModTime().UTC()
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	site.index = site.entries["/index.html"]
	if site.index == nil {
		return nil, os.ErrNotExist
	}
	site.notFound = site.entries["/404.html"]
	if site.notFound == nil {
		site.notFound = site.index
	}
	if site.modTime.IsZero() {
		site.modTime = time.Now().UTC()
	}
	return site, nil
}

// resolve mirrors the static resolution the front proxy used to perform, so
// that Caddy no longer needs a separate file_server: exact path, then
// {path}.html for an extensionless request, plus /favicon.ico -> favicon.svg.
// A path that filepath.Clean would rewrite is treated as a miss, exactly as
// before. It never falls back to the index for arbitrary paths.
func (s *staticSite) resolve(requestPath string) *staticEntry {
	if requestPath == "" || requestPath[0] != '/' {
		return nil
	}
	if path.Clean(requestPath) != requestPath || strings.Contains(requestPath, "\\") {
		return nil
	}
	if entry := s.entries[requestPath]; entry != nil {
		return entry
	}
	if requestPath == "/favicon.ico" {
		return s.entries["/favicon.svg"]
	}
	if filepath.Ext(requestPath) == "" {
		if entry := s.entries[requestPath+".html"]; entry != nil {
			return entry
		}
	}
	return nil
}

func contentTypeFor(relative string) string {
	if value := mime.TypeByExtension(filepath.Ext(relative)); value != "" {
		return value
	}
	return "application/octet-stream"
}

// cacheControl is one site-wide rule applied identically to every static
// entry, the index and the 404 body: anything with a query string or any 4xx
// is uncacheable, everything else is cacheable. It never depends on whether a
// request carried a bridge capability, so /?bridge=x and /about?x get the same
// header. This also closes the browser-fallback caching gap.
func cacheControl(r *http.Request, status int) string {
	if status >= 400 || r.URL.RawQuery != "" {
		return "no-store"
	}
	return "public, max-age=300"
}

// serveEntry writes one in-memory entry with the single uniform header set
// used for the whole static surface, handling HEAD and If-Modified-Since the
// same way for every path. No ETag or Accept-Ranges is emitted for any entry.
func (s *Server) serveEntry(
	w http.ResponseWriter,
	r *http.Request,
	entry *staticEntry,
	status int) {
	header := w.Header()
	header.Set("Cache-Control", cacheControl(r, status))
	header.Set("Content-Security-Policy", "default-src 'self'; style-src 'self'; img-src 'self'; worker-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
	header.Set("Referrer-Policy", "strict-origin-when-cross-origin")
	header.Set("X-Content-Type-Options", "nosniff")
	header.Set("X-Frame-Options", "DENY")
	header.Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
	header.Set("Content-Type", entry.contentType)
	header.Set("Last-Modified", s.site.modTime.UTC().Format(http.TimeFormat))
	if status == http.StatusOK && notModified(r, s.site.modTime) {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	header.Set("Content-Length", strconv.Itoa(len(entry.body)))
	w.WriteHeader(status)
	if r.Method != http.MethodHead {
		_, _ = w.Write(entry.body)
	}
}

func notModified(r *http.Request, modTime time.Time) bool {
	value := r.Header.Get("If-Modified-Since")
	if value == "" {
		return false
	}
	since, err := http.ParseTime(value)
	if err != nil {
		return false
	}
	return !modTime.Truncate(time.Second).After(since)
}

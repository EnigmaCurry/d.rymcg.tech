package traefik_shared_url_auth

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Config holds exactly what you declare in your Traefik dynamic config
type Config struct {
	CookieName string `json:"cookieName,omitempty"`
	JWTSecret  string `json:"jwtSecret,omitempty"`
	JWTExpires string `json:"jwtExpires,omitempty"`
	QueryParam string `json:"queryParam,omitempty"`
	URLExpires string `json:"urlExpires,omitempty"`
}

// CreateConfig just returns an empty struct—Traefik will fill it from your static config
func CreateConfig() *Config {
	return &Config{}
}

type sharedURLAuth struct {
	next        http.Handler
	cookieName  string
	jwtSecret   []byte
	jwtExpires  time.Duration
	urlExpires  time.Duration
	queryParam  string
}

func New(ctx context.Context, next http.Handler, config *Config, name string) (http.Handler, error) {
	// 1) Validate required
	if config.JWTSecret == "" {
		return nil, fmt.Errorf("shared-url-auth: jwtSecret must be set")
	}

	// 2) Apply defaults for anything missing
	cookieName := config.CookieName
	if cookieName == "" {
		cookieName = "shared_url_auth"
	}
	queryParam := config.QueryParam
	if queryParam == "" {
		queryParam = "token"
	}

	// 3) Parse durations
	jwtDur, err := time.ParseDuration(config.JWTExpires)
	if err != nil || jwtDur <= 0 {
		jwtDur = 15 * time.Minute
	}
	urlDur, err := time.ParseDuration(config.URLExpires)
	if err != nil {
		// zero means “never expire” or “not enforced”
		urlDur = 0
	}

	return &sharedURLAuth{
		next:       next,
		cookieName: cookieName,
		jwtSecret:  []byte(config.JWTSecret),
		jwtExpires: jwtDur,
		urlExpires: urlDur,
		queryParam: queryParam,
	}, nil
}

func (a *sharedURLAuth) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Extract from URL
	tokenString := r.URL.Query().Get(a.queryParam)
	fromURL := tokenString != ""

	// Fallback to cookie
	if !fromURL {
		if c, err := r.Cookie(a.cookieName); err == nil {
			tokenString = c.Value
		}
	}
	
    if tokenString == "" {
        http.Error(w, "Unauthorized — no token provided", http.StatusUnauthorized)
        return
    }

	// Parse & verify
	claims := &jwt.RegisteredClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return a.jwtSecret, nil
	})
	if err != nil || !token.Valid {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	// Enforce URL expiry window if presented via URL
	if fromURL && a.urlExpires > 0 && claims.IssuedAt != nil {
		if time.Since(claims.IssuedAt.Time) > a.urlExpires {
			http.Error(w, "Link expired", http.StatusForbidden)
			return
		}
	}

	// Set cookie on first‐time URL access
	if fromURL {
		http.SetCookie(w, &http.Cookie{
			Name:     a.cookieName,
			Value:    tokenString,
			Path:     "/",
			HttpOnly: true,
			MaxAge:   int(a.jwtExpires.Seconds()),
			Secure: true,
		})
	}

	// Forward
	a.next.ServeHTTP(w, r)
}

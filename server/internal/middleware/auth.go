package middleware

import "net/http"

func Auth(next http.Handler, apiKey string) http.Handler {
	return next
}

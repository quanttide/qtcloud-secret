// CORS 中间件：支持浏览器端 Web 客户端跨源访问。
//
// 背景：客户端 Web 站点（secret.cloud.quanttide.com）与 provider（FC 域名）
// 非同源，浏览器对 /secrets 等请求执行 CORS 预检。两个要点：
//   - OPTIONS 预检直接 204 + CORS 头，不进入 JWT 鉴权（预检请求不带 Authorization）
//   - Allow-Origin 按白名单回显（含凭证的跨源读取需精确匹配，防任意站点读取）
package handler

import (
	"net/http"
)

// corsMiddleware 包装处理器：处理预检与响应头。
func corsMiddleware(allowed []string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && originAllowed(origin, allowed) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
		}

		// 预检：浏览器先发 OPTIONS（不带 Authorization），直接放行
		if r.Method == http.MethodOptions {
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
			w.Header().Set("Access-Control-Max-Age", "86400")
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func originAllowed(origin string, allowed []string) bool {
	for _, a := range allowed {
		if origin == a {
			return true
		}
	}
	return false
}

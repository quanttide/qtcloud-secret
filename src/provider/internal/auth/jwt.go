// Package auth 实现无状态 JWT 验签。
//
// 设计（见 docs/index.md「认证」）：
//   - 用户在外部子系统（qtcloud-auth），本服务不建账号、不存会话
//   - 每请求 Authorization: Bearer <JWT>，验签公钥/密钥与 qtcloud-auth 对齐
//   - 线上 qtcloud-auth 为 RS256 非对称签名（JWT_PRIVATE_KEY 签发，见
//     quanttide-auth「JWT 升级 RS256 非对称签名」）；本服务用 JWT_PUBLIC_KEY
//     公钥验签。未配置公钥时回落 HS256（JWT_SECRET 共享，本地开发/旧环境）
//   - 校验 exp；预留 scope 供团队版细粒度权限
package auth

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

// Claims 认可的 JWT 声明。scope 预留：团队版细粒度权限（当前阶段验签通过即可读写）。
type Claims struct {
	Scope string `json:"scope,omitempty"`
	jwt.RegisteredClaims
}

// Verifier 校验 JWT 签名与声明：RS256（JWT_PUBLIC_KEY 公钥）优先，
// HS256（JWT_SECRET 共享）回落。
type Verifier struct {
	secret    []byte
	publicKey *rsa.PublicKey
}

// NewJWTVerifier 创建验签器。
//
// publicKeyPEM 为 qtcloud-auth 的 RS256 验签公钥（PEM）；为空时使用
// secret（HS256）验签。两者都缺失时返回错误。
func NewJWTVerifier(secret []byte, publicKeyPEM []byte) (*Verifier, error) {
	var pub *rsa.PublicKey
	if len(publicKeyPEM) > 0 {
		block, _ := pem.Decode(publicKeyPEM)
		if block == nil {
			return nil, errors.New("JWT_PUBLIC_KEY PEM 解码失败")
		}
		key, err := x509.ParsePKIXPublicKey(block.Bytes)
		if err != nil {
			return nil, fmt.Errorf("JWT_PUBLIC_KEY 公钥解析失败: %w", err)
		}
		rsaKey, ok := key.(*rsa.PublicKey)
		if !ok {
			return nil, errors.New("JWT_PUBLIC_KEY 不是 RSA 公钥")
		}
		pub = rsaKey
	}
	if pub == nil && len(secret) < 16 {
		return nil, errors.New("JWT_SECRET 长度不足（至少 16 字节）且未配置 JWT_PUBLIC_KEY")
	}
	return &Verifier{secret: secret, publicKey: pub}, nil
}

// Verify 验签并校验 exp，返回 JWT 声明。
func (v *Verifier) Verify(tokenString string) (*Claims, error) {
	claims := &Claims{}
	_, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (any, error) {
		switch t.Method.(type) {
		case *jwt.SigningMethodRSA:
			if v.publicKey == nil {
				return nil, errors.New("收到 RS256 令牌但未配置 JWT_PUBLIC_KEY")
			}
			return v.publicKey, nil
		case *jwt.SigningMethodHMAC:
			return v.secret, nil
		default:
			return nil, fmt.Errorf("意外的签名算法: %v", t.Header["alg"])
		}
	})
	if err != nil {
		return nil, fmt.Errorf("JWT 验签失败: %w", err)
	}
	return claims, nil
}

// Middleware 从 Authorization 头提取并验签，通过后注入声明到上下文。
func (v *Verifier) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			http.Error(w, "缺少 Bearer 令牌", http.StatusUnauthorized)
			return
		}
		claims, err := v.Verify(strings.TrimPrefix(header, "Bearer "))
		if err != nil {
			http.Error(w, "令牌无效: "+err.Error(), http.StatusUnauthorized)
			return
		}
		// 当前阶段：验签通过即可读写（单团队）；scope 预留团队版权限
		_ = claims
		next.ServeHTTP(w, r)
	})
}

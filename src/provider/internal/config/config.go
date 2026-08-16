// Package config 从环境变量加载服务端配置。
//
// 环境变量约定（与 manifests/terraform/fc.tf 一致）：
//
//	OSS_BUCKET          密文数据桶名
//	OSS_ENDPOINT        OSS endpoint（如 https://oss-cn-hangzhou.aliyuncs.com）
//	JWT_PUBLIC_KEY      qtcloud-auth 的 JWT RS256 验签公钥（base64(PEM) 单行，对齐 auth 的 JWT_PRIVATE_KEY 注入方式）
//	JWT_SECRET          与 qtcloud-auth 共享的 JWT HS256 签名密钥（org secret；仅 JWT_PUBLIC_KEY 未配置时回落）
//	MASTER_KEY          服务端主密钥（base64 32 字节，AES-256-GCM 加密 secret 字段；运维资产，丢失可重置）
//	CORS_ALLOWED_ORIGINS 浏览器跨源白名单（逗号分隔；默认本产品 Web 站点，见下）
//	PORT                监听端口（默认 8080，FC custom-container 约定）
package config

import (
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"os"
	"strings"
)

// Config 服务端运行配置。
type Config struct {
	OSSBucket         string
	OSSEndpoint       string
	JWTPublicKey      []byte // JWT RS256 验签公钥 PEM（qtcloud-auth 线上签名方案）
	JWTSecret         []byte // JWT HS256 签名密钥（仅公钥未配置时回落）
	MasterKey         []byte // 服务端主密钥（AES-256-GCM 加密 secret 字段）
	CORSAllowedOrigin []string
	Port              string
}

// Load 从环境变量加载配置并校验必填项。
func Load() (*Config, error) {
	cfg := &Config{
		OSSBucket:   os.Getenv("OSS_BUCKET"),
		OSSEndpoint: os.Getenv("OSS_ENDPOINT"),
		Port:        os.Getenv("PORT"),
	}
	if cfg.Port == "" {
		cfg.Port = "8080"
	}

	if cfg.OSSBucket == "" {
		return nil, fmt.Errorf("环境变量 OSS_BUCKET 未设置")
	}
	if cfg.OSSEndpoint == "" {
		return nil, fmt.Errorf("环境变量 OSS_ENDPOINT 未设置")
	}

	// JWT 验签：线上 qtcloud-auth 为 RS256 非对称签名（JWT_PRIVATE_KEY 签发），
	// 本服务用其公钥验签（JWT_PUBLIC_KEY，base64(PEM) 单行，与 auth 注入方式对齐）。
	if b64 := os.Getenv("JWT_PUBLIC_KEY"); b64 != "" {
		pem, err := base64.StdEncoding.DecodeString(b64)
		if err != nil {
			return nil, fmt.Errorf("JWT_PUBLIC_KEY base64 解码失败: %w", err)
		}
		cfg.JWTPublicKey = pem
	}

	// HS256 回落：仅当未配置公钥时使用（本地开发/旧环境；与 qtcloud-auth 历史
	// getEnv fallback 保持一致）。生产务必配置 JWT_PUBLIC_KEY。
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "quanttide-auth-secret"
	}
	cfg.JWTSecret = []byte(secret)

	// 服务端主密钥（AES-256-GCM）：MASTER_KEY 为 base64 32 字节（运维注入）。
	// 未配置时使用本地开发默认值（SHA-256 派生，仅本地调试，生产必须注入）。
	mk := os.Getenv("MASTER_KEY")
	if mk == "" {
		sum := sha256.Sum256([]byte("quanttide-local-dev-master-key"))
		mk = base64.StdEncoding.EncodeToString(sum[:])
	}
	key, err := base64.StdEncoding.DecodeString(mk)
	if err != nil {
		return nil, fmt.Errorf("MASTER_KEY base64 解码失败: %w", err)
	}
	if len(key) != 32 {
		return nil, fmt.Errorf("MASTER_KEY 解码后必须为 32 字节（当前 %d）", len(key))
	}
	cfg.MasterKey = key

	// 浏览器跨源白名单（Web 客户端站点）；未配置时默认本产品 Web 域名
	origins := os.Getenv("CORS_ALLOWED_ORIGINS")
	if origins == "" {
		origins = "https://secret.cloud.quanttide.com,http://secret.cloud.quanttide.com"
	}
	for _, o := range strings.Split(origins, ",") {
		if o = strings.TrimSpace(o); o != "" {
			cfg.CORSAllowedOrigin = append(cfg.CORSAllowedOrigin, o)
		}
	}

	return cfg, nil
}

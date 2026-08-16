// Package crypto 服务端主密钥加解密（放弃零知识后的应用层加密）。
//
// 设计（docs/dev-guide/security.md「服务端加密」）：
//   - 主密钥 MASTER_KEY（base64 32 字节）由运维注入环境变量，
//     是运维资产而非用户资产——丢失可重置（重加密全部条目）
//   - 每条目随机 nonce（12 字节）AES-256-GCM 加密 secret 字段；
//     密文含 GCM 认证标签（16 字节），篡改即解密失败
//   - OSS 侧仍有 SSE-OSS 静态加密 + 私有 ACL：应用层加密是第二层防线
package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
)

// Encrypt 用主密钥加密明文，返回 base64 nonce 与密文（含 GCM tag）。
func Encrypt(key, plaintext []byte) (nonceB64, cipherB64 string, err error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", "", fmt.Errorf("初始化 AES 失败: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", "", fmt.Errorf("初始化 GCM 失败: %w", err)
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", "", fmt.Errorf("生成 nonce 失败: %w", err)
	}
	sealed := gcm.Seal(nil, nonce, plaintext, nil)
	return base64.StdEncoding.EncodeToString(nonce),
		base64.StdEncoding.EncodeToString(sealed), nil
}

// Decrypt 用主密钥解密（GCM 认证失败返回错误）。
func Decrypt(key []byte, nonceB64, cipherB64 string) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("初始化 AES 失败: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("初始化 GCM 失败: %w", err)
	}
	nonce, err := base64.StdEncoding.DecodeString(nonceB64)
	if err != nil {
		return nil, errors.New("nonce 不是合法 base64")
	}
	ciphertext, err := base64.StdEncoding.DecodeString(cipherB64)
	if err != nil {
		return nil, errors.New("密文不是合法 base64")
	}
	plain, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return nil, fmt.Errorf("解密失败（密钥不匹配或数据被篡改）: %w", err)
	}
	return plain, nil
}

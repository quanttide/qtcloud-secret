// Package model 定义机密条目对象结构（服务端加密方案）。
//
// 设计（见 docs/dev-guide/model.md）：
//   - name 明文存储（列表展示用）；secret 字段由服务端主密钥
//     AES-256-GCM 加密（internal/crypto），运维管理主密钥
//   - 客户端经 JWT 登录后直接读写（不再有客户端密钥派生）
package model

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"time"
)

// SecretItem 存储对象：secrets/<id>.json。
type SecretItem struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Secret    Encrypted `json:"secret"` // 服务端主密钥加密的 secret 字段
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// Encrypted 服务端加密负载（nonce + 密文，均 base64）。
type Encrypted struct {
	Nonce      string `json:"nonce"`
	Ciphertext string `json:"ciphertext"`
}

// 校验规则。
const (
	MaxItemSize   = 64 * 1024 // 存储对象大小上限 64 KB
	MaxNameLength = 256       // name 长度上限
	MaxSecretSize = 32 * 1024 // secret 明文上限 32 KB
)

var (
	uuidV4Re = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$`)
	base64Re = regexp.MustCompile(`^[A-Za-z0-9+/]*={0,2}$`)
)

// Validate 校验存储对象结构。
func (s *SecretItem) Validate() error {
	if !uuidV4Re.MatchString(s.ID) {
		return errors.New("id 必须是 UUID v4")
	}
	if s.Name == "" || len(s.Name) > MaxNameLength {
		return fmt.Errorf("name 长度必须在 1-%d 之间", MaxNameLength)
	}
	if s.Secret.Nonce == "" || !base64Re.MatchString(s.Secret.Nonce) {
		return errors.New("secret.nonce 必须是 base64 字符串")
	}
	if s.Secret.Ciphertext == "" || !base64Re.MatchString(s.Secret.Ciphertext) {
		return errors.New("secret.ciphertext 必须是 base64 字符串")
	}
	if n, err := base64.StdEncoding.DecodeString(s.Secret.Ciphertext); err == nil && len(n) == 0 {
		return errors.New("secret.ciphertext 为空")
	}
	return nil
}

// ParseItem 解析并校验存储对象（含大小上限）。
func ParseItem(body []byte) (*SecretItem, error) {
	if len(body) == 0 || len(body) > MaxItemSize {
		return nil, fmt.Errorf("请求体大小必须在 1-%d 字节之间", MaxItemSize)
	}
	var s SecretItem
	if err := json.Unmarshal(body, &s); err != nil {
		return nil, fmt.Errorf("非法 JSON: %w", err)
	}
	if err := s.Validate(); err != nil {
		return nil, err
	}
	return &s, nil
}

// SecretRequest 客户端写入请求（id 仅更新时需带——创建时服务端生成，客户端不感知）。
type SecretRequest struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Secret string `json:"secret"`
}

// Validate 校验写入请求。
func (r *SecretRequest) Validate() error {
	// id 可选：创建时为空（服务端生成 UUID v4），更新时须与路径一致（handler 校验）
	if r.ID != "" && !uuidV4Re.MatchString(r.ID) {
		return errors.New("id 必须是 UUID v4")
	}
	if r.Name == "" || len(r.Name) > MaxNameLength {
		return fmt.Errorf("name 长度必须在 1-%d 之间", MaxNameLength)
	}
	if r.Secret == "" || len(r.Secret) > MaxSecretSize {
		return fmt.Errorf("secret 长度必须在 1-%d 之间", MaxSecretSize)
	}
	return nil
}

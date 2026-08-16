// Package handler 实现 /secrets 的 REST 处理器（服务端加密方案）。
//
// 链路（见 docs/dev-guide/transfer.md）：
//
//	客户端 {name, secret 明文} → POST/PUT → 本服务主密钥加密 → OSS
//	客户端 ← GET（列表/单个，secret 已解密） ← 本服务解密代理
//
// 服务端可信：客户端经 qtcloud-auth 登录（JWT）后直接读写明文，
// secret 字段在服务端用 MASTER_KEY（AES-256-GCM）加密落盘（内部 crypto 包）。
package handler

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/quanttide/quanttide-secret/provider/internal/auth"
	"github.com/quanttide/quanttide-secret/provider/internal/crypto"
	"github.com/quanttide/quanttide-secret/provider/internal/model"
	"github.com/quanttide/quanttide-secret/provider/internal/storage"
)

const (
	secretsPrefix = "secrets/"
	objectKey     = "id" // URL 路径参数名
)

// Handler 聚合依赖的 REST 处理器。
type Handler struct {
	verifier       *auth.Verifier
	store          storage.Store
	masterKey      []byte // 服务端主密钥（加密 secret 字段）
	allowedOrigins []string
}

// New 创建处理器。
func New(verifier *auth.Verifier, store storage.Store, masterKey []byte, allowedOrigins []string) *Handler {
	return &Handler{verifier: verifier, store: store, masterKey: masterKey, allowedOrigins: allowedOrigins}
}

// Routes 注册路由（Go 1.22+ 方法路由）；secrets 端点经 JWT 验签中间件，/health 免鉴权（探活用）。
// CORS 中间件在最外层：OPTIONS 预检直接放行（不经过 JWT）。
func (h *Handler) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	secured := http.NewServeMux()
	secured.HandleFunc("GET /secrets", h.list)
	secured.HandleFunc("POST /secrets", h.create)
	secured.HandleFunc("GET /export", h.export)
	secured.HandleFunc("GET /secrets/{id}", h.get)
	secured.HandleFunc("PUT /secrets/{id}", h.update)
	secured.HandleFunc("DELETE /secrets/{id}", h.delete)
	mux.Handle("/", h.verifier.Middleware(secured))
	return corsMiddleware(h.allowedOrigins, mux)
}

// list GET /secrets：返回清单（id/name/updatedAt），客户端列表展示。
func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	metas, err := h.store.List(r.Context(), secretsPrefix)
	if err != nil {
		h.audit(r, "list", "", "失败: "+err.Error())
		http.Error(w, "列表失败", http.StatusInternalServerError)
		return
	}
	type item struct {
		ID        string    `json:"id"`
		Name      string    `json:"name"`
		UpdatedAt time.Time `json:"updatedAt"`
	}
	out := make([]item, 0, len(metas))
	for _, m := range metas {
		id := strings.TrimPrefix(m.Key, secretsPrefix)
		name := id
		// 读取条目取 name（小数据量，列表轻量全量读）
		if data, err := h.store.Get(r.Context(), m.Key); err == nil {
			if it, perr := model.ParseItem(data); perr == nil {
				name = it.Name
			}
		}
		out = append(out, item{ID: id, Name: name, UpdatedAt: m.UpdatedAt})
	}
	h.audit(r, "list", "", "成功")
	writeJSON(w, http.StatusOK, out)
}

// export GET /export：导出全部条目明文（NDJSON 流式，离线备份用）。
func (h *Handler) export(w http.ResponseWriter, r *http.Request) {
	metas, err := h.store.List(r.Context(), secretsPrefix)
	if err != nil {
		h.audit(r, "export", "", "失败: "+err.Error())
		http.Error(w, "导出失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/x-ndjson")
	w.Header().Set("Content-Disposition", `attachment; filename="qtcloud-secret-backup.ndjson"`)

	exported, skipped := 0, 0
	for _, m := range metas {
		item, err := h.decryptItem(r, m.Key)
		if err != nil {
			skipped++
			h.audit(r, "export", m.Key, "跳过: "+err.Error())
			continue
		}
		data, _ := json.Marshal(item)
		if _, err := w.Write(append(data, '\n')); err != nil {
			h.audit(r, "export", m.Key, "写入中断: "+err.Error())
			return
		}
		exported++
	}
	h.audit(r, "export", "", fmt.Sprintf("成功 导出=%d 跳过=%d", exported, skipped))
}

// create POST /secrets：校验 → 服务端生成 UUID → 主密钥加密 → OSS。
func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	req, err := parseRequest(w, r)
	if err != nil {
		h.audit(r, "create", "", "校验失败: "+err.Error())
		return
	}
	// id 由服务端生成（客户端不感知 UUID，避免客户端拼错格式）
	if req.ID == "" {
		req.ID = newUUID()
	}
	item, err := h.encryptItem(req, time.Now().UTC())
	if err != nil {
		h.audit(r, "create", req.ID, "加密失败: "+err.Error())
		http.Error(w, "加密失败", http.StatusInternalServerError)
		return
	}
	body, _ := json.Marshal(item)
	if err := h.store.Put(r.Context(), secretsPrefix+item.ID, body); err != nil {
		h.audit(r, "create", item.ID, "失败: "+err.Error())
		http.Error(w, "写入失败", http.StatusInternalServerError)
		return
	}
	h.audit(r, "create", item.ID, "成功")
	writeJSON(w, http.StatusCreated, map[string]any{"id": item.ID, "updatedAt": item.UpdatedAt})
}

// get GET /secrets/{id}：读取并解密返回明文条目。
func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue(objectKey)
	item, err := h.decryptItem(r, secretsPrefix+id)
	if err != nil {
		h.audit(r, "get", id, "失败: "+err.Error())
		if err == storage.ErrNotFound {
			http.Error(w, "对象不存在", http.StatusNotFound)
		} else {
			http.Error(w, "读取失败", http.StatusInternalServerError)
		}
		return
	}
	h.audit(r, "get", id, "成功")
	writeJSON(w, http.StatusOK, item)
}

// update PUT /secrets/{id}：保留 createdAt，重加密覆盖写。
func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue(objectKey)
	req, err := parseRequest(w, r)
	if err != nil {
		h.audit(r, "update", id, "校验失败: "+err.Error())
		return
	}
	if req.ID != id {
		h.audit(r, "update", id, "校验失败: id 与路径不一致")
		http.Error(w, "id 与路径不一致", http.StatusBadRequest)
		return
	}
	// 保留 createdAt（旧对象存在时）
	createdAt := time.Now().UTC()
	if old, err := h.store.Get(r.Context(), secretsPrefix+id); err == nil {
		if it, perr := model.ParseItem(old); perr == nil {
			createdAt = it.CreatedAt
		}
	}
	item, err := h.encryptItem(req, createdAt)
	if err != nil {
		h.audit(r, "update", id, "加密失败: "+err.Error())
		http.Error(w, "加密失败", http.StatusInternalServerError)
		return
	}
	body, _ := json.Marshal(item)
	if err := h.store.Put(r.Context(), secretsPrefix+id, body); err != nil {
		h.audit(r, "update", id, "失败: "+err.Error())
		http.Error(w, "写入失败", http.StatusInternalServerError)
		return
	}
	h.audit(r, "update", id, "成功")
	writeJSON(w, http.StatusOK, map[string]any{"id": id, "updatedAt": item.UpdatedAt})
}

// delete DELETE /secrets/{id}：物理删除（OSS delete marker 兜底恢复）。
func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue(objectKey)
	if err := h.store.Delete(r.Context(), secretsPrefix+id); err != nil {
		h.audit(r, "delete", id, "失败: "+err.Error())
		if err == storage.ErrNotFound {
			http.Error(w, "对象不存在", http.StatusNotFound)
		} else {
			http.Error(w, "删除失败", http.StatusInternalServerError)
		}
		return
	}
	h.audit(r, "delete", id, "成功")
	w.WriteHeader(http.StatusNoContent)
}

// ── 加解密辅助 ─────────────────────────────────────────────

// newUUID 生成 UUID v4（CSPRNG，version 4 + variant 10），作为对象 key。
func newUUID() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		// crypto/rand 失败属于系统级故障，直接 panic 让实例重启（不留半成品）
		panic("crypto/rand 读取失败: " + err.Error())
	}
	b[6] = (b[6] & 0x0f) | 0x40 // version 4
	b[8] = (b[8] & 0x3f) | 0x80 // variant 10
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

// 明文条目（客户端交互 DTO：secret 为明文）。
type secretDTO struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Secret    string    `json:"secret"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// encryptItem 明文请求 → 主密钥加密的存储对象。
func (h *Handler) encryptItem(req *model.SecretRequest, createdAt time.Time) (*model.SecretItem, error) {
	nonce, ciphertext, err := crypto.Encrypt(h.masterKey, []byte(req.Secret))
	if err != nil {
		return nil, err
	}
	return &model.SecretItem{
		ID:        req.ID,
		Name:      req.Name,
		Secret:    model.Encrypted{Nonce: nonce, Ciphertext: ciphertext},
		CreatedAt: createdAt,
		UpdatedAt: time.Now().UTC(),
	}, nil
}

// decryptItem 存储对象 → 解密返回明文 DTO。
func (h *Handler) decryptItem(r *http.Request, key string) (*secretDTO, error) {
	data, err := h.store.Get(r.Context(), key)
	if err != nil {
		return nil, err
	}
	it, err := model.ParseItem(data)
	if err != nil {
		return nil, err
	}
	plain, err := crypto.Decrypt(h.masterKey, it.Secret.Nonce, it.Secret.Ciphertext)
	if err != nil {
		return nil, err
	}
	return &secretDTO{
		ID:        it.ID,
		Name:      it.Name,
		Secret:    string(plain),
		CreatedAt: it.CreatedAt,
		UpdatedAt: it.UpdatedAt,
	}, nil
}

// parseRequest 读取并校验写入请求体（大小上限 + 结构）。
func parseRequest(w http.ResponseWriter, r *http.Request) (*model.SecretRequest, error) {
	body, err := io.ReadAll(io.LimitReader(r.Body, model.MaxItemSize+1))
	if err != nil {
		http.Error(w, "读取请求体失败", http.StatusBadRequest)
		return nil, err
	}
	if len(body) > model.MaxItemSize {
		http.Error(w, "请求体过大", http.StatusRequestEntityTooLarge)
		return nil, errTooLarge
	}
	var req model.SecretRequest
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, "非法 JSON", http.StatusBadRequest)
		return nil, err
	}
	if err := req.Validate(); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return nil, err
	}
	return &req, nil
}

var errTooLarge = &http.MaxBytesError{}

// audit 审计日志（当前阶段：标准日志输出；团队版/合规要求时落独立审计存储）。
func (h *Handler) audit(r *http.Request, action, id, result string) {
	log.Printf("audit method=%s action=%s id=%s result=%s remote=%s", r.Method, action, id, result, r.RemoteAddr)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

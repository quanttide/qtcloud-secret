# CHANGELOG

所有显著变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)（发布规范见 qtcloud-devops `docs/tutorial/source/conventions/changelog.md`）。

版本遵循语义化版本规范：0.0.x（探索期）→ 0.x.y（验证期）→ x.y.z（正式期）

---

## [Unreleased]

（待发布内容将在此累积）

---

## [0.1.0-alpha.6] - 2026-08-16

### Changed
- **放弃零知识架构，改为服务端加密**（单团队内部系统，服务端可信）：
  - secret 字段由服务端主密钥（MASTER_KEY，AES-256-GCM）加密落盘，OSS 私有 + SSE-OSS 双保险
  - 主密钥是运维资产（base64 32 字节环境变量），丢失可重置重加密，不再依赖用户保管
- API 简化：POST/PUT 提交 `{id, name, secret 明文}`；GET 返回明文条目（登录即用）；清单含 name
- 客户端不再需要主密码/恢复码（登录后直接读写）

### Added
- `MASTER_KEY` 环境变量 + terraform `master_key` 变量（CI 从 org secret MASTER_KEY 注入）

---

## [0.1.0-alpha.5] - 2026-08-16

### Added
- CORS 支持：浏览器端 Web 客户端（secret.cloud.quanttide.com）跨源访问 provider；OPTIONS 预检直接放行（不经过 JWT 鉴权），Allow-Origin 按白名单回显（`CORS_ALLOWED_ORIGINS` 环境变量，默认本产品 Web 站点）

---

## [0.1.0-alpha.4] - 2026-08-16

### Fixed
- 线上登录 401（客户端提示服务端异常）：qtcloud-auth 已升级 RS256 非对称签名（JWT_PRIVATE_KEY 签发，见 quanttide-auth「JWT 升级 RS256」），provider 仍按 HS256 共享密钥验签导致不匹配
- JWT 验签对齐线上 auth：新增 `JWT_PUBLIC_KEY`（base64(PEM) RSA 公钥）RS256 验签；未配置时回落 HS256（JWT_SECRET，本地/旧环境）

### Changed
- CI 部署：`TF_VAR_jwt_public_key` 由 org secret `JWT_PRIVATE_KEY` 在流水线内派生（openssl rsa -pubout，base64 单行），不新增 secret、私钥不落日志
- terraform：新增 `jwt_public_key` 变量（sensitive，默认空）注入 FC 环境变量

## [0.1.0-alpha.3] - 2026-08-16

### Fixed
- OSS 访问 500：SDK 凭证读取适配 FC 3.0 运行时角色凭证（ALIBABA_CLOUD_* STS），本地开发仍支持 OSS_ACCESS_KEY_*

## [0.1.0-alpha.2] - 2026-08-16

### Fixed
- 部署未生效问题：FC 镜像缓存导致同 tag 不重新拉取，HS256 认证修复未随 alpha.1 生效；本版本以新 tag 发布确保新镜像被拉取
- `GET /health` 移出 JWT 鉴权中间件（探活免鉴权）

## [0.1.0-alpha.1] - 2026-08-16

### Added
- 服务端 `src/provider`（Go）：JWT 验签（与 qtcloud-auth 共享 `JWT_SECRET`，HS256）、代理 OSS 读写（`/secrets` CRUD）、导出备份（`GET /export`，NDJSON 流式）
- 部署 IaC `manifests/terraform`：OSS 数据桶（版本控制 + SSE-OSS 二次加密 + 生命周期清理）+ FC 3.0 应用服务（custom-container，纯 OSS 无数据库）
- 架构文档 `docs/dev-guide/`：产品定位、存储选型、传输架构、数据模型、零知识安全设计（含 Vault 定位与边界）
- 用户手册 `docs/user-guide/`：备份与恢复指南（Emergency Kit / 受托恢复）
- CI 流水线 `.github/workflows/deploy-provider.yml`：tag `provider/*` 触发（镜像双通道发布 + Terraform apply）

### Changed
- JWT 认证对齐 qtcloud-auth：RS256 公钥方案改为共享 `JWT_SECRET`（HS256），含 fallback 默认值对齐

### Fixed
- Dockerfile 基础镜像对齐 go.mod 工具链要求（go ≥ 1.25），支持 GOPROXY 构建参数覆盖（解决 CI 构建失败）
- 部署后 FC 环境变量缺失导致的启动失败（JWT 密钥注入问题）

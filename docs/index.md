# 客户端设计思路（studio）

> 本文档说明量潮机密云客户端（`src/studio`，Flutter）的设计思路。
> 服务端设计见 `src/provider/docs/index.md`，架构总纲见 `docs/dev-guide/`。

## 1. 定位与职责

客户端是**服务端加密架构**的接入端：登录后直接读写明文（服务端以 MASTER_KEY 加密落盘），
无任何客户端密钥负担（架构说明见 dev-guide/security.md）。

| 职责 | 说明 |
|------|------|
| ✅ 认证 | 引导用户经外部子系统（qtcloud-auth）登录，携带 JWT 访问 provider |
| ✅ 列表/查看 | 拉取清单（id/name）与条目明文，登录即用 |
| ✅ 新建/编辑 | 提交 `{name, secret}` 明文，服务端加密落盘 |
| ✅ 本地缓存 | 明文条目内存缓存（列表/查看），锁定/退出清空，不落盘 |
| ✅ 同步 | 全量拉取清单 + 差异拉取（小数据量，无需增量协议） |
| ✅ 备份 | 导出明文 NDJSON（`GET /export`）离线保管 |
| ❌ 客户端密钥 | 无——密钥是服务端运维资产（MASTER_KEY） |

## 2. 技术选型

| 项 | 选型 | 说明 |
|----|------|------|
| 框架 | Flutter 3.x | 跨平台（Windows/macOS/iOS/Android/Web），与 qtcloud-delib studio 一致 |
| HTTP | `http` | 对接 provider API（`/secrets` CRUD、`/export`） |
| 本地存储 | 内存缓存（明文条目，登录后拉取） | 锁定/退出清空，不落盘；无客户端加密/派生依赖 |

## 3. 模块划分

```
lib/
├── main.dart                 # 入口：登录/列表状态驱动
├── auth/
│   └── session.dart          # 外部子系统登录（OAuth/token）+ JWT 存取
├── api/
│   └── provider_client.dart  # /secrets CRUD + /export（Bearer JWT，明文 DTO）
├── store/
│   └── local_cache.dart      # 明文条目内存缓存（登录后拉取）
└── ui/
    ├── login_page.dart       # 登录（账号密码）
    ├── secret_list_page.dart # 条目列表（查看/复制/删除/编辑）
    ├── secret_edit_page.dart # 新建/编辑条目
    └── backup_page.dart      # 导出/恢复备份（明文 NDJSON）
```

## 4. 核心数据流

### 4.1 创建/更新条目

```
① 用户输入名称 + 密码 → 内存
② POST /secrets（服务端生成 UUID）→ provider 校验 + MASTER_KEY 加密 → OSS
③ 响应 id 入本地缓存 → UI 刷新
编辑：PUT /secrets/{id}（保留 createdAt，重加密覆盖写）
```

### 4.2 登录与列表（登录即用）

页面由 AppState 状态驱动：

```
登录页（LoginPage）：账号 + 账号密码 → qtcloud-auth 认证 → 会话（JWT）
  → 拉取清单（GET /secrets）→ 直接进入列表页
列表页（SecretListPage）：条目立即可见，点击查看/复制明文、新建/编辑/删除、
  备份恢复全部直接可用（无客户端密钥环节）
```

- 登录即会话：数据由服务端 MASTER_KEY 加密落盘，客户端无密钥负担
- 锁定仅清除内存缓存（明文不落盘），会话保留；退出登录才回到登录页
- 所有页面均不暴露任何服务端地址（编译期 dart-define 注入）

```
① 点击条目 → 明文对话框（复制到剪贴板）→ 剪贴板自动清除（建议 30s）/ 自动锁屏
② 下拉刷新 → 全量清单 + 差异拉取 → 内存缓存更新
```

### 4.3 备份与恢复

- **备份**：`GET /export` 拉取全部条目明文（NDJSON）→ 复制保存为文件（加密压缩保管）
- **恢复**：粘贴备份内容 → 逐条上传合并（按 id 幂等覆盖）
- **主密钥丢失处置**：见 [user-guide/master-key.md](user-guide/master-key.md)

## 5. 安全设计

| 机制 | 实现 |
|------|------|
| 明文生命周期 | 解密结果仅内存、用后即焚；剪贴板复制自动过期 |
| 自动锁屏 | 无操作 N 分钟后清除内存缓存，会话保留（登录即恢复） |
| 生物识别 | 可选：登录润滑层（依赖 auth 侧能力） |
| 本地缓存 | 明文条目内存缓存；锁定/退出清空，不落盘 |
| 防截屏 | 敏感页面禁用截图（平台能力，可选） |
| 会话 | JWT 短时效 + 过期重新登录；token 不落盘明文（系统安全存储） |

## 6. 与 provider 的接口约定

| 端点 | 客户端用途 |
|------|-----------|
| `GET /secrets` | 全量同步清单（id/updatedAt） |
| `POST /secrets` / `PUT /secrets/{id}` | 创建（服务端生成 id）/更新（body = 明文条目） |
| `GET /secrets/{id}` | 读取单个条目（明文） |
| `GET /export` | 导出全部条目明文（NDJSON，离线备份） |
| `DELETE /secrets/{id}` | 删除 |
| `GET /health` | 服务可用性检查 |

认证：`Authorization: Bearer <JWT>`（qtcloud-auth 签发，HS256 共享 JWT_SECRET，见 provider docs）。

**服务地址配置（安全原则）**：所有服务端地址均为部署配置，编译期注入（`--dart-define=PROVIDER_BASE_URL` / `AUTH_BASE_URL`），**UI 不提供任何地址编辑入口、不暴露内部服务地址**——单团队部署下地址固定，改环境即重新构建。演进：provider 增加 `GET /auth-config` 发现端点后，客户端仅需配置 provider 地址，认证端点由服务端引导（对齐"用户在外部子系统，对客户端透明"的架构）。

## 7. 演进预留

| 未来需求 | 预留方式 |
|----------|---------|
| 团队版共享 | 信封加密升级为 DEK 公钥包裹（密钥来源从"派生"换"解包"），crypto 层接口不变 |
| 受托恢复 | Emergency Kit 模块扩展 Shamir 碎片（接收/汇聚/重构） |
| 增量同步 | sync 模块预留 sync_token 参数位（当前全量） |
| 多保险库 | 信封增加 vaultId 字段，索引与 UI 按 vault 分组 |

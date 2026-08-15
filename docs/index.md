# 客户端设计思路（studio）

> 本文档说明量潮机密云客户端（`src/studio`，Flutter）的设计思路。
> 服务端设计见 `src/provider/docs/index.md`，架构总纲见 `docs/dev-guide/`。

## 1. 定位与职责

客户端是零知识架构的**信任根**：所有明文与密钥只存在于客户端。服务端（provider）只存储和转发密文信封，对内容一无所知。

| 职责 | 说明 |
|------|------|
| ✅ 加密/解密 | 主密码派生密钥，AES-256-GCM 加解密条目（明文只在内存） |
| ✅ 密钥管理 | 主密码、盐、nonce 的生成与生命周期（见 dev-guide/security.md） |
| ✅ 认证 | 引导用户经外部子系统（qtcloud-auth）登录，携带 JWT 访问 provider |
| ✅ 本地缓存与索引 | 密文本地缓存 + 明文索引（列表/搜索），支持离线查看 |
| ✅ 同步 | 全量拉取密文清单，差异合并（小数据量，无需增量协议） |
| ✅ 备份 | Emergency Kit 引导、导出加密备份（`GET /export`） |
| ❌ 明文落盘 | 解密结果不落盘，仅内存驻留 |

## 2. 技术选型

| 项 | 选型 | 说明 |
|----|------|------|
| 框架 | Flutter 3.x | 跨平台（Windows/macOS/iOS/Android/Web），与 qtcloud-delib studio 一致 |
| 加密 | `cryptography` 包（AES-256-GCM） | 纯 Dart 实现，跨平台一致 |
| 密钥派生 | Argon2id | `argon2` 包（dart 实现）；参数与 provider 信封的 `kdfSalt` 配合 |
| HTTP | `http` / `dio` | 对接 provider API（`/secrets` CRUD、`/export`） |
| 本地存储 | `sqflite` / `drift`（元数据索引）+ 文件（密文缓存） | 明文索引仅存内存派生视图，不落盘 |

## 3. 模块划分

```
lib/
├── main.dart                 # 入口：锁屏状态机（锁定/解锁）
├── crypto/
│   ├── key_derivation.dart   # Argon2id 派生 + 盐管理
│   ├── envelope.dart         # 信封加解密（AES-256-GCM，对齐 model.md 结构）
│   └── emergency_kit.dart    # Emergency Kit 生成/解析（恢复码）
├── auth/
│   └── session.dart          # 外部子系统登录（OAuth/token）+ JWT 存取
├── api/
│   ├── provider_client.dart  # /secrets CRUD + /export（Bearer JWT）
│   └── models.dart           # 信封 DTO（与服务端 schema 一致）
├── store/
│   ├── local_cache.dart      # 密文本地缓存 + 元数据索引
│   └── sync.dart             # 全量同步（列表差异合并）
└── ui/
    ├── unlock_page.dart      # 主密码解锁（生物识别可选的润滑层）
    ├── secret_list_page.dart # 条目列表（本地索引搜索）
    ├── secret_edit_page.dart # 新建/编辑条目
    └── backup_page.dart      # 导出备份 + Emergency Kit 引导
```

## 4. 核心数据流

### 4.1 创建/更新条目

```
① 用户输入明文密码 → 内存
② 随机生成 salt + nonce → Argon2id(主密码, salt) 派生密钥
③ AES-256-GCM 加密 → 密文信封（id/name/时间戳/encrypted 负载）
④ POST/PUT /secrets → provider 校验外层结构 → OSS
⑤ 信封加入本地缓存 → UI 刷新（明文立即从内存清除）
```

### 4.2 登录、解锁与读取

**登录与解锁分离**（两阶段，页面由 AppState 状态驱动）：

```
登录页（LoginPage）：账号 + 账号密码 → qtcloud-auth 认证 → 会话（JWT）
解锁页（UnlockPage）：主密码 + 恢复码 → Argon2id 派生 → 全量同步解密
```

- 登录只验证「你是谁」（外部子系统身份），不接触任何密钥材料
- 解锁只验证「你有没有密钥」（本地派生），不出现账号密码
- 锁定仅清除密钥材料，会话保留——重新解锁无需再登录；退出登录才回到登录页
- 两个页面均不暴露任何服务端地址（编译期 dart-define 注入）

```
① 解锁页输入主密码+恢复码 → Argon2id 派生（每次解锁重新派生，锁定时内存清零）
② 进入前台/手动刷新 → GET /secrets 清单 → 差异拉取密文
③ 点击条目 → GET /secrets/{id}（或本地缓存）→ AES-GCM 解密 → 明文仅内存展示
④ 复制密码/超时 → 剪贴板自动清除（建议 30s）/ 自动锁屏
```

### 4.3 备份与恢复

- **备份**：`GET /export` 拉取全部密文信封（NDJSON）→ 保存为加密备份文件（用户自保管）
- **恢复**：导入备份文件 → 输入主密码 → 逐行解密合并到本地
- **Emergency Kit**：注册时强制引导生成（恢复码 + 使用说明），本地打印/导出

## 5. 安全设计

| 机制 | 实现 |
|------|------|
| 明文生命周期 | 解密结果仅内存、用后即焚；剪贴板复制自动过期 |
| 自动锁屏 | 无操作 N 分钟后锁定，解锁需重新输入主密码 |
| 生物识别 | Face ID / 指纹作为解锁润滑层（底层仍需主密码，不替代） |
| 本地缓存 | 密文缓存 + 元数据索引；明文索引不落盘 |
| 防截屏 | 敏感页面禁用截图（平台能力，可选） |
| 会话 | JWT 短时效 + 过期重新登录；token 不落盘明文（系统安全存储） |

## 6. 与 provider 的接口约定

| 端点 | 客户端用途 |
|------|-----------|
| `GET /secrets` | 全量同步清单（id/updatedAt） |
| `POST /secrets` / `PUT /secrets/{id}` | 创建/更新（body = 密文信封） |
| `GET /secrets/{id}` | 读取单个密文信封 |
| `GET /export` | 导出全部密文（NDJSON，离线备份） |
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

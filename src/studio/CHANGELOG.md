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
- **放弃零知识架构，改为服务端加密**（对齐 provider v0.1.0-alpha.6）：
  - 移除客户端全部密钥链路：主密码/恢复码/解锁页/设置页密钥管理/Argon2id 派生（argon2_web、cryptography 依赖一并移除）
  - 登录即用：登录（qtcloud-auth）后直接列表/查看/新建/编辑，数据由服务端 MASTER_KEY 加密落盘
  - 编辑页直接预填现有明文（此前编辑不显示旧值）；长按条目可编辑
  - 备份页导出明文 NDJSON、恢复逐条上传（无解密环节）
  - 锁定仅清除内存缓存，会话保留

### Removed
- `crypto/`（key_derivation/envelope/emergency_kit）、`store/sync.dart`、`ui/unlock_page.dart`、`ui/settings_page.dart` 及相关测试

---

## [0.1.0-alpha.5] - 2026-08-16

### Added
- 设置页（列表页右上角设置入口）：密钥管理
  - 恢复码生成器：CSPRNG 生成 20 字符恢复码 + 一键复制（任何状态下可用）
  - 修改密钥：新主密码 + 新恢复码 → 全部条目旧密钥解密、新密钥重加密并上传（不可逆，操作前确认弹窗；需已解锁）
  - 未解锁时提示"去解锁"后即可修改

---

## [0.1.0-alpha.4] - 2026-08-16

### Changed
- 新建/编辑条目不再预先拦截解锁：直接进入编辑页填写（编辑不预填明文，名称来自明文元数据），点保存时（加密需要派生密钥）才按需弹出解锁页，成功即保存

---

## [0.1.0-alpha.3] - 2026-08-16

### Added
- 登录后直接进入资源列表：清单元数据（name 等）为明文字段，无需密钥即可浏览；查看明文/新建编辑/备份恢复等需密钥操作时按需弹出解锁页，成功后返回原操作
- 列表页未解锁横幅（提示按需解锁）

### Changed
- 解锁页由顶层页面改为模态页（pop(true) 返回调用方；新增「取消」）
- 锁定仅清除密钥材料与明文索引，密文信封缓存保留——资源列表仍可见，重新解锁无需重新登录（此前锁定会清空列表）
- 同步引擎拆分：syncMetas（清单元数据，不解密）+ syncAll（元数据 + 解密）；下拉刷新在未解锁时仅同步元数据

---

## [0.1.0-alpha.2] - 2026-08-16

### Changed
- 产品名全面更名：密码云 → 机密云（客户端标题、Web 描述、Emergency Kit、FC 描述等；领域范围扩大至密码、证件、密钥与敏感信息等机密对象）

## [0.1.0-alpha.1] - 2026-08-16

### Added
- 初始化 Flutter 客户端项目（`src/studio`，全平台：Windows/macOS/iOS/Android/Web）
- 客户端设计文档 `docs/index.md`（零知识信任根、数据流、安全设计、接口约定）
- 零知识加密链路：Argon2id 密钥派生（恢复码双因子参与）+ AES-256-GCM 信封加解密（随机 salt/nonce，GCM 认证防篡改）
- Emergency Kit 生成（CSPRNG 恢复码 + 可打印说明）
- 认证与 API 客户端：qtcloud-auth 登录（OAuth2 password）→ provider CRUD（/secrets、/export）
- 同步引擎：全量清单差异合并 + 内存明文索引（锁定时清除，不落盘）
- UI 全流程：登录页（账号密码）→ 解锁页（主密码+恢复码）→ 条目列表（下拉刷新/查看复制/删除）→ 新建编辑 → 备份导出/恢复导入
- 单元与冒烟测试：派生/加解密往返/篡改检测/Emergency Kit/登录解锁页分离（14 项）
- 部署流水线 `.github/workflows/deploy-studio.yml`：tag `studio/*` 触发（Flutter Web 构建 + OSS 静态网站发布 + CDN 刷新，域名 secret.cloud.quanttide.com）

### Changed
- 文档更名：密码云 → 机密云（领域范围扩大至密码、证件、密钥与敏感信息等机密对象）
- 登录与解锁分离为两阶段：登录页仅账号密码（qtcloud-auth 会话认证），解锁页仅主密码+恢复码（本地密钥派生）；锁定保留会话、重新解锁无需再登录，退出登录回登录页；页面切换由 AppState 状态驱动
- 服务端地址全部收敛为编译期配置（`--dart-define` 注入），UI 不再暴露任何服务端地址（provider/auth 均不硬编码、无编辑入口）

### Fixed
- Argon2id 参数适配 argon2 包 API（lanes 并行道）
- Web 构建失败：argon2 1.0.1（ffi）dart2js 64 位整型字面量无法编译 → 全平台统一迁移至 argon2_web 0.3.0（纯 Dart Web-safe 实现，支持 secret 双因子；与旧实现逐字节对比一致，桌面/Web 数据互通；固定向量测试锁定数据兼容性契约）

## 已知事项

- （无）

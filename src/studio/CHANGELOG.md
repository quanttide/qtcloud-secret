# CHANGELOG

所有显著变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

## [Unreleased]

### Added
- 初始化 Flutter 客户端项目（`src/studio`，全平台：Windows/macOS/iOS/Android/Web）
- 客户端设计文档 `docs/index.md`（零知识信任根、数据流、安全设计、接口约定）
- 零知识加密链路：Argon2id 密钥派生（恢复码双因子参与）+ AES-256-GCM 信封加解密（随机 salt/nonce，GCM 认证防篡改）
- Emergency Kit 生成（CSPRNG 恢复码 + 可打印说明）
- 认证与 API 客户端：qtcloud-auth 登录（OAuth2 password）→ provider CRUD（/secrets、/export）
- 同步引擎：全量清单差异合并 + 内存明文索引（锁定时清除，不落盘）
- UI 全流程：解锁（登录 + 主密码 + 恢复码）→ 条目列表（下拉刷新/查看复制/删除）→ 新建编辑 → 备份导出/恢复导入
- 单元测试：派生/加解密往返/篡改检测/Emergency Kit（13 项）

### Changed
- 解锁流程接通真实认证与同步（此前为占位）

### Fixed
- Argon2id 参数适配 argon2 包 API（lanes 并行道）

## 已知事项

- Web 平台构建受 argon2 包 dart2js 兼容性限制（64 位整型字面量），桌面/移动端不受影响；后续可换 wasm 实现（argon2_browser）

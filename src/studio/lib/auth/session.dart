// 会话管理：外部子系统（qtcloud-auth）登录与 JWT 存取。
//
// 设计（docs/index.md 6）：Authorization: Bearer <JWT>
// - token 短时效，过期重新登录；不落盘明文（系统安全存储）
//
// TODO: 接入 qtcloud-auth OAuth 流程；token 安全存储（flutter_secure_storage）。
library;

class Session {
  const Session({required this.accessToken});

  final String accessToken;
}

// provider API 客户端：密文信封的 CRUD 与导出。
//
// 端点约定（src/provider/docs/index.md）：
//   GET/POST /secrets、GET/PUT/DELETE /secrets/{id}、GET /export、GET /health
// 请求体为密文信封 JSON（模型见 crypto/envelope.dart）。
//
// TODO: 接入 http/dio；错误码映射（400/401/404/413/500）；超时与重试。
library;

class ProviderClient {
  const ProviderClient({required this.baseUrl, required this.session});

  final String baseUrl;
  final Object session;
}

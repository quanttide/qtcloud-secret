// 认证客户端：对接外部子系统（qtcloud-auth）获取 JWT。
//
// 端点（qtcloud-auth /oauth/token，OAuth2 password 模式）：
//   POST /oauth/token  form: grant_type=password&username=&password=
//   → {"access_token": "...", "token_type": "Bearer", ...}
// 返回的 access_token 用于访问 provider API（Authorization: Bearer）。
import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthClient {
  AuthClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// 账号密码登录，返回 JWT access token。
  Future<String> login({
    required String username,
    required String password,
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/oauth/token'),
      body: {'grant_type': 'password', 'username': username, 'password': password},
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );
    if (resp.statusCode != 200) {
      throw AuthException('登录失败（${resp.statusCode}）：${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const AuthException('登录响应缺少 access_token');
    }
    return token;
  }
}

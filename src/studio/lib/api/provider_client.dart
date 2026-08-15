// provider API 客户端：密文信封的 CRUD 与导出。
//
// 端点约定（src/provider/docs/index.md）：
//   GET/POST /secrets、GET/PUT/DELETE /secrets/{id}、GET /export、GET /health
// 认证：Authorization: Bearer <JWT>（qtcloud-auth 签发，见 auth/session.dart）。
// 零知识红线：本层只传输密文信封，永不接触明文。
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../crypto/envelope.dart';

class ProviderException implements Exception {
  const ProviderException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProviderClient {
  ProviderClient({required this.baseUrl, required this.token, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// 健康检查。
  Future<bool> health() async {
    final resp = await _client.get(Uri.parse('$baseUrl/health'));
    return resp.statusCode == 200;
  }

  /// 全量清单（id/updatedAt），同步用。
  Future<List<SecretMeta>> list() async {
    final resp = await _client.get(Uri.parse('$baseUrl/secrets'), headers: _headers);
    if (resp.statusCode != 200) {
      throw ProviderException('列表失败（${resp.statusCode}）');
    }
    final data = jsonDecode(resp.body) as List<dynamic>;
    return data
        .map((e) => SecretMeta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 读取单个密文信封。
  Future<Envelope> get(String id) async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/secrets/$id'),
      headers: _headers,
    );
    if (resp.statusCode == 404) {
      throw ProviderException('条目不存在');
    }
    if (resp.statusCode != 200) {
      throw ProviderException('读取失败（${resp.statusCode}）');
    }
    return Envelope.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// 创建条目。
  Future<void> create(Envelope envelope) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/secrets'),
      headers: _headers,
      body: jsonEncode(envelope.toJson()),
    );
    if (resp.statusCode != 201) {
      throw ProviderException('创建失败（${resp.statusCode}）：${resp.body}');
    }
  }

  /// 更新条目（覆盖写）。
  Future<void> update(Envelope envelope) async {
    final resp = await _client.put(
      Uri.parse('$baseUrl/secrets/${envelope.id}'),
      headers: _headers,
      body: jsonEncode(envelope.toJson()),
    );
    if (resp.statusCode != 200) {
      throw ProviderException('更新失败（${resp.statusCode}）：${resp.body}');
    }
  }

  /// 删除条目。
  Future<void> delete(String id) async {
    final resp = await _client.delete(
      Uri.parse('$baseUrl/secrets/$id'),
      headers: _headers,
    );
    if (resp.statusCode != 204) {
      throw ProviderException('删除失败（${resp.statusCode}）');
    }
  }

  /// 导出全部密文信封（NDJSON 文本，离线备份用）。
  Future<String> export() async {
    final resp = await _client.get(Uri.parse('$baseUrl/export'), headers: _headers);
    if (resp.statusCode != 200) {
      throw ProviderException('导出失败（${resp.statusCode}）');
    }
    return resp.body;
  }
}

/// 清单条目（对齐 provider /secrets 响应）。
class SecretMeta {
  const SecretMeta({required this.id, required this.updatedAt});

  final String id;
  final DateTime updatedAt;

  factory SecretMeta.fromJson(Map<String, dynamic> json) => SecretMeta(
        id: json['id'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

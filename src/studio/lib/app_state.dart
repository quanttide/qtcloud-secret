// 应用状态：会话与数据缓存的持有者（服务端加密方案，无客户端密钥）。
//
// 流程：登录（qtcloud-auth 认证）→ 拉取清单/条目（服务端解密返回明文）
// → 列表/查看/新建/编辑直接可用；锁定仅清内存缓存，会话保留。
// 服务端地址均为编译期配置（--dart-define 注入），UI 不暴露。
import 'package:flutter/foundation.dart';

import '../api/provider_client.dart';
import '../auth/session.dart';
import '../store/local_cache.dart';

/// 编译期服务地址（dart-define 注入，不在 UI 暴露）：
///   flutter run --dart-define=PROVIDER_BASE_URL=https://... --dart-define=AUTH_BASE_URL=...
///
/// 安全原则：所有服务端地址都是部署配置，UI 不提供编辑入口——
/// 单团队部署下地址固定，由构建注入；改环境即重新构建。
class AppConfig {
  static const providerBaseUrl = String.fromEnvironment(
    'PROVIDER_BASE_URL',
    defaultValue: 'https://qtcloudret-prod-lsqtuthybh.cn-hangzhou.fcapp.run',
  );

  /// 认证服务地址：仅 dart-define 注入（默认空，不硬编码内部服务地址）。
  static const authBaseUrl = String.fromEnvironment('AUTH_BASE_URL');
}

/// 会话状态：登录（持有 JWT）即可用（服务端加密，无客户端密钥）。
class AppState extends ChangeNotifier {
  AppState();

  bool _loggedIn = false;
  String? _token;
  ProviderClient? _client;
  LocalCache? _cache;

  bool get loggedIn => _loggedIn;
  LocalCache get cache => _cache!;
  ProviderClient get client => _client!;

  /// 登录：qtcloud-auth 账号密码认证 → 组装客户端 → 拉取清单。
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final authBaseUrl = AppConfig.authBaseUrl;
    if (authBaseUrl.isEmpty) {
      throw StateError(
        '未配置认证服务地址：请通过 --dart-define=AUTH_BASE_URL=... 注入',
      );
    }
    final auth = AuthClient(baseUrl: authBaseUrl);
    _token = await auth.login(username: username, password: password);
    _client = ProviderClient(baseUrl: AppConfig.providerBaseUrl, token: _token!);
    _cache = LocalCache();
    await _cache!.syncAll(_client!);
    _loggedIn = true;
    notifyListeners();
  }

  /// 刷新清单与条目缓存（下拉刷新用）。
  Future<void> refresh() async {
    await _cache!.syncAll(_client!);
    notifyListeners();
  }

  /// 锁定：清除内存缓存（明文），会话保留。
  void lock() {
    _cache?.clearAll();
    notifyListeners();
  }

  /// 退出登录：清除会话与缓存，回到登录页。
  void logout() {
    _cache?.clearAll();
    _cache = null;
    _client = null;
    _token = null;
    _loggedIn = false;
    notifyListeners();
  }

  /// 测试钩子：模拟已登录（不经网络认证；列表为空，不触发同步）。
  @visibleForTesting
  void debugSetLoggedIn() {
    _token = 'test-token';
    _client = ProviderClient(baseUrl: 'http://localhost', token: 'test-token');
    _cache = LocalCache();
    _loggedIn = true;
    notifyListeners();
  }
}

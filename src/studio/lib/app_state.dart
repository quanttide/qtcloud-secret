// 应用状态：会话、密钥材料与同步引擎的持有者。
//
// 零知识边界：主密码/恢复码/派生密钥只存在于本对象（内存），
// 锁定时全部清除。服务端地址均为编译期配置（--dart-define 注入），
// 不在 UI 暴露：见下方 AppConfig。
import 'package:flutter/foundation.dart';

import '../api/provider_client.dart';
import '../auth/session.dart';
import '../store/local_cache.dart';
import '../store/sync.dart';

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

/// 会话状态：锁定（未解锁）时不含任何密钥材料。
class AppState extends ChangeNotifier {
  AppState();

  bool _unlocked = false;
  String? _masterPassword;
  String? _recoveryCode;
  ProviderClient? _client;
  LocalCache? _cache;
  SyncEngine? _sync;

  bool get unlocked => _unlocked;
  LocalCache get cache => _cache!;
  SyncEngine get sync => _sync!;
  ProviderClient get client => _client!;

  /// 解锁：登录获取 JWT → 组装客户端 → 全量同步。
  Future<void> unlock({
    required String username,
    required String password,
    required String masterPassword,
    required String recoveryCode,
  }) async {
    final authBaseUrl = AppConfig.authBaseUrl;
    if (authBaseUrl.isEmpty) {
      throw StateError(
        '未配置认证服务地址：请通过 --dart-define=AUTH_BASE_URL=... 注入',
      );
    }
    final auth = AuthClient(baseUrl: authBaseUrl);
    final token = await auth.login(username: username, password: password);
    _masterPassword = masterPassword;
    _recoveryCode = recoveryCode;
    _client = ProviderClient(baseUrl: AppConfig.providerBaseUrl, token: token);
    _cache = LocalCache();
    _sync = SyncEngine(client: _client!, cache: _cache!);
    await _sync!.syncAll(
      masterPassword: masterPassword,
      recoveryCode: recoveryCode,
    );
    _unlocked = true;
    notifyListeners();
  }

  /// 锁定：内存密钥材料全部清除（明文索引随之清空）。
  void lock() {
    _unlocked = false;
    _masterPassword = null;
    _recoveryCode = null;
    _cache?.clear();
    _cache = null;
    _sync = null;
    _client = null;
    notifyListeners();
  }

  /// 当前密钥材料（仅解锁后可用；供 UI 层传递，避免页面持有）。
  (String, String) get keyMaterial =>
      (_masterPassword!, _recoveryCode!);
}

/// 列表展示条目（明文元数据视图）。
class SecretListEntry {
  const SecretListEntry({required this.id, required this.name});

  final String id;
  final String name;
}

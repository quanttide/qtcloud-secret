// 应用状态：会话、密钥材料与同步引擎的持有者。
//
// 零知识边界：主密码/恢复码/派生密钥只存在于本对象（内存），
// 锁定时全部清除。服务端地址通过 --dart-define 注入：
//   flutter run --dart-define=PROVIDER_BASE_URL=... --dart-define=AUTH_BASE_URL=...
import 'package:flutter/foundation.dart';

import '../api/provider_client.dart';
import '../auth/session.dart';
import '../store/local_cache.dart';
import '../store/sync.dart';

/// 编译期服务地址（dart-define 可覆盖）。
class AppConfig {
  static const providerBaseUrl = String.fromEnvironment(
    'PROVIDER_BASE_URL',
    defaultValue: 'https://qtcloudret-prod-lsqtuthybh.cn-hangzhou.fcapp.run',
  );
  static const authBaseUrl = String.fromEnvironment(
    'AUTH_BASE_URL',
    defaultValue: 'https://qtclouduth-prod-gnuguyxinh.cn-hangzhou.fcapp.run',
  );
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
    required String authBaseUrl,
    required String providerBaseUrl,
    required String username,
    required String password,
    required String masterPassword,
    required String recoveryCode,
  }) async {
    final auth = AuthClient(baseUrl: authBaseUrl);
    final token = await auth.login(username: username, password: password);
    _masterPassword = masterPassword;
    _recoveryCode = recoveryCode;
    _client = ProviderClient(baseUrl: providerBaseUrl, token: token);
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

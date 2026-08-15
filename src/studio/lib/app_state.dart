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

/// 会话状态：登录（持有 JWT）与解锁（持有密钥材料）分离。
///
/// 流程（对齐「先见资源，需解密时才解锁」）：
///   登录 → 组装客户端 + 同步清单元数据（name 等明文元数据，不解密）
///   → 直接进入列表页；点击条目/新建/备份等需要密钥的操作时再解锁
/// 锁定只清除密钥材料与明文索引（密文信封缓存保留，列表仍可见），
/// 会话保留——重新解锁无需再登录。
class AppState extends ChangeNotifier {
  AppState();

  bool _loggedIn = false;
  bool _unlocked = false;
  String? _token;
  String? _masterPassword;
  String? _recoveryCode;
  ProviderClient? _client;
  LocalCache? _cache;
  SyncEngine? _sync;

  bool get loggedIn => _loggedIn;
  bool get unlocked => _unlocked;
  LocalCache get cache => _cache!;
  SyncEngine get sync => _sync!;
  ProviderClient get client => _client!;

  /// 登录：qtcloud-auth 账号密码认证 → 组装客户端 → 同步清单元数据。
  ///
  /// 不派生密钥、不解密任何数据——资源清单（明文元数据）登录后立即可见。
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
    _sync = SyncEngine(client: _client!, cache: _cache!);
    await _sync!.syncMetas();
    _loggedIn = true;
    notifyListeners();
  }

  /// 解锁：主密码+恢复码派生密钥 → 全量同步解密。
  Future<void> unlock({
    required String masterPassword,
    required String recoveryCode,
  }) async {
    final token = _token;
    if (token == null) {
      throw StateError('未登录：请先在登录页完成账号认证');
    }
    _masterPassword = masterPassword;
    _recoveryCode = recoveryCode;
    await _sync!.syncAll(
      masterPassword: masterPassword,
      recoveryCode: recoveryCode,
    );
    _unlocked = true;
    notifyListeners();
  }

  /// 锁定：清除密钥材料与明文索引，保留登录会话与密文信封缓存
  /// （资源清单仍可见，点击条目时重新解锁）。
  void lock() {
    _unlocked = false;
    _masterPassword = null;
    _recoveryCode = null;
    _cache?.clear();
    notifyListeners();
  }

  /// 退出登录：清除会话、密钥材料与全部缓存，回到登录页。
  void logout() {
    _unlocked = false;
    _masterPassword = null;
    _recoveryCode = null;
    _cache?.clearAll();
    _cache = null;
    _sync = null;
    _client = null;
    _token = null;
    _loggedIn = false;
    notifyListeners();
  }

  /// 当前密钥材料（仅解锁后可用；供 UI 层传递，避免页面持有）。
  (String, String) get keyMaterial =>
      (_masterPassword!, _recoveryCode!);

  /// 更新会话密钥材料（设置页「修改密钥」重加密完成后调用——
  /// 此后加密/解密均使用新密钥，锁定后解锁也需输入新密钥）。
  void setKeyMaterial(String masterPassword, String recoveryCode) {
    _masterPassword = masterPassword;
    _recoveryCode = recoveryCode;
    notifyListeners();
  }

  /// 测试钩子：模拟已登录（不经网络认证；列表为空，不触发同步）。
  @visibleForTesting
  void debugSetLoggedIn() {
    _token = 'test-token';
    _client = ProviderClient(baseUrl: 'http://localhost', token: 'test-token');
    _cache = LocalCache();
    _sync = SyncEngine(client: _client!, cache: _cache!);
    _loggedIn = true;
    notifyListeners();
  }
}

/// 列表展示条目（明文元数据视图）。
class SecretListEntry {
  const SecretListEntry({required this.id, required this.name});

  final String id;
  final String name;
}

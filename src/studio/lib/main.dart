import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/login_page.dart';
import 'ui/secret_list_page.dart';
import 'ui/unlock_page.dart';

void main() {
  runApp(SecretApp(state: AppState()));
}

/// 量潮密码云客户端入口。
///
/// 设计思路见 docs/index.md：
/// 客户端是零知识信任根——明文与密钥只存在于本端，
/// 服务端（provider）只存储密文信封。
///
/// 页面由 AppState 状态驱动（不依赖导航栈）：
///   未登录 → 登录页（账号密码）→ 已登录未解锁 → 解锁页（主密码+恢复码）
///   → 已解锁 → 条目列表页；锁定回到解锁页，退出登录回到登录页。
class SecretApp extends StatelessWidget {
  const SecretApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '量潮密码云',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (!state.loggedIn) {
            return LoginPage(state: state);
          }
          if (!state.unlocked) {
            return UnlockPage(state: state);
          }
          return SecretListPage(state: state);
        },
      ),
    );
  }
}

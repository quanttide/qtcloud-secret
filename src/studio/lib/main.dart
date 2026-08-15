import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/login_page.dart';
import 'ui/secret_list_page.dart';

void main() {
  runApp(SecretApp(state: AppState()));
}

/// 量潮机密云客户端入口。
///
/// 设计思路见 docs/index.md：
/// 客户端是零知识信任根——明文与密钥只存在于本端，
/// 服务端（provider）只存储密文信封。
///
/// 页面由 AppState 状态驱动（不依赖导航栈）：
///   未登录 → 登录页（账号密码）；已登录 → 列表页（资源清单立即可见，
///   元数据为明文无需密钥；点击条目/新建/备份时按需解锁，见 UnlockPage）。
class SecretApp extends StatelessWidget {
  const SecretApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '量潮机密云',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (!state.loggedIn) {
            return LoginPage(state: state);
          }
          return SecretListPage(state: state);
        },
      ),
    );
  }
}

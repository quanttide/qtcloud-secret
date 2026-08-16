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
/// 服务端加密方案——客户端经 qtcloud-auth 登录后直接读写
/// （服务端以 MASTER_KEY 加密落盘），无客户端密钥。
///
/// 页面由 AppState 状态驱动（不依赖导航栈）：
///   未登录 → 登录页（账号密码）；已登录 → 列表页（登录即用）。
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

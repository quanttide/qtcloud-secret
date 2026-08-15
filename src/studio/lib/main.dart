import 'package:flutter/material.dart';

import 'ui/unlock_page.dart';

void main() {
  runApp(const SecretApp());
}

/// 量潮密码云客户端入口。
///
/// 设计思路见 docs/index.md：
/// 客户端是零知识信任根——明文与密钥只存在于本端，
/// 服务端（provider）只存储密文信封。启动即进入锁定态。
class SecretApp extends StatelessWidget {
  const SecretApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '量潮密码云',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const UnlockPage(),
    );
  }
}

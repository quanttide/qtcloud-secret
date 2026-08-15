import 'package:flutter/material.dart';

/// 条目编辑页：新建/编辑密码条目。
///
/// 设计（docs/index.md 4.1）：明文仅在内存，
/// 保存时加密为信封后经 provider API 上传。TODO: 接入 crypto 与 api 层。
class SecretEditPage extends StatelessWidget {
  const SecretEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建条目')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: '名称')),
            TextField(
              decoration: InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
          ],
        ),
      ),
    );
  }
}

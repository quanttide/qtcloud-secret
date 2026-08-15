import 'package:flutter/material.dart';

/// 条目列表页：本地明文索引展示（解锁后派生）。
///
/// 设计（docs/index.md 4.2）：列表/搜索基于内存明文索引，
/// 点击条目后解密展示。TODO: 接入 store 层与编辑页导航。
class SecretListPage extends StatelessWidget {
  const SecretListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的密码')),
      body: const Center(child: Text('暂无条目')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 跳转新建条目页
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

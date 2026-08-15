import 'package:flutter/material.dart';

/// 解锁页：主密码入口（零知识信任根）。
///
/// 设计（docs/index.md 4.2）：
/// - 每次解锁重新派生密钥（Argon2id），锁定时内存清零
/// - 生物识别（Face ID/指纹）仅作润滑层，底层仍需主密码
/// - TODO: 接入 crypto/key_derivation.dart 与 store/local_cache.dart
class UnlockPage extends StatelessWidget {
  const UnlockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('量潮密码云')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 16),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '主密码',
                  hintText: '输入主密码解锁',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  // TODO: 派生密钥 → 加载本地缓存 → 进入条目列表
                },
                child: const Text('解锁'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

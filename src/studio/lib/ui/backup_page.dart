import 'package:flutter/material.dart';

/// 备份页：导出加密备份 + Emergency Kit 引导。
///
/// 设计（docs/index.md 4.3）：
/// - 备份：GET /export 拉取全部密文（NDJSON）保存为加密备份文件
/// - 恢复：导入备份 → 主密码逐行解密合并
/// - Emergency Kit：注册时强制引导（恢复码 + 使用说明）
/// TODO: 接入 api/ProviderClient 与 crypto/EmergencyKit。
class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () {
                // TODO: 导出加密备份
              },
              icon: const Icon(Icons.download),
              label: const Text('导出加密备份'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: 导入备份恢复
              },
              icon: const Icon(Icons.upload),
              label: const Text('从备份恢复'),
            ),
          ],
        ),
      ),
    );
  }
}

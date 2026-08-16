import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/provider_client.dart';
import '../app_state.dart';

/// 备份页：导出明文备份 + 从备份恢复（服务端加密方案）。
///
/// 设计（docs/index.md 4.3）：
/// - 备份：GET /export 拉取全部条目（NDJSON 明文）→ 复制保存
/// - 恢复：粘贴 NDJSON → 逐条上传合并（幂等覆盖）
class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.state});

  final AppState state;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  final _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final ndjson = await widget.state.client.export();
      await Clipboard.setData(ClipboardData(text: ndjson));
      if (mounted) {
        setState(() {
          _message =
              '已导出 ${ndjson.trim().isEmpty ? 0 : ndjson.trim().split('\n').length} 条条目并复制到剪贴板'
              '（保存为 .ndjson 文件即可离线备份）';
          _messageIsError = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = '导出失败：$e';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    final text = _importController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _message = '请先粘贴备份内容（NDJSON）';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      var imported = 0;
      for (final line in const LineSplitter().convert(text)) {
        if (line.trim().isEmpty) {
          continue;
        }
        final item = SecretItem.fromJson(jsonDecode(line) as Map<String, dynamic>);
        await widget.state.client.update(item); // 幂等覆盖
        widget.state.cache.put(item);
        imported++;
      }
      if (mounted) {
        setState(() {
          _message = '已恢复 $imported 条条目';
          _messageIsError = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = '恢复失败：$e（请确认备份内容完整）';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.download),
            label: const Text('导出备份（明文 NDJSON）'),
          ),
          const SizedBox(height: 24),
          const Text('从备份恢复（粘贴 NDJSON 内容）：'),
          const SizedBox(height: 8),
          TextField(
            controller: _importController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '粘贴 qtcloud-secret-backup.ndjson 的内容',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.upload),
            label: const Text('从备份恢复'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _message!,
                style: TextStyle(
                  color: _messageIsError
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            '备份为明文 NDJSON：请妥善保管（加密文件/离线介质）。'
            '数据由服务端主密钥加密落盘，备份文件是明文副本。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

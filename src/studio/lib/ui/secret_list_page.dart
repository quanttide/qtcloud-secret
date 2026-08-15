import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import 'backup_page.dart';
import 'secret_edit_page.dart';

/// 条目列表页：本地明文索引展示 + 全量同步。
///
/// 设计（docs/index.md 4.2）：列表基于内存明文索引（name 为明文元数据），
/// 点击条目解密显示密码并可复制（剪贴板自动过期由系统/后续实现）。
class SecretListPage extends StatefulWidget {
  const SecretListPage({super.key, required this.state});

  final AppState state;

  @override
  State<SecretListPage> createState() => _SecretListPageState();
}

class _SecretListPageState extends State<SecretListPage> {
  Future<void> _sync() async {
    try {
      final (master, recovery) = widget.state.keyMaterial;
      await widget.state.sync.syncAll(
        masterPassword: master,
        recoveryCode: recovery,
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败：$e')),
        );
      }
    }
  }

  Future<void> _showSecret(SecretListEntry entry) async {
    final (master, recovery) = widget.state.keyMaterial;
    try {
      final plaintext = await widget.state.sync.decrypt(
        entry.id,
        master,
        recovery,
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(entry.name),
          content: SelectableText(plaintext),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: plaintext));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
                Navigator.of(context).pop();
              },
              child: const Text('复制'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解密失败：$e')),
        );
      }
    }
  }

  Future<void> _delete(SecretListEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${entry.name}」？'),
        content: const Text('删除后可从服务端版本控制恢复（如有）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.state.client.delete(entry.id);
      widget.state.cache.remove(entry.id);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
    }
  }

  Future<void> _openEdit([SecretListEntry? entry]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SecretEditPage(state: widget.state, existing: entry),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.state.cache.all
        .map((e) => SecretListEntry(id: e.id, name: e.name))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的密码'),
        actions: [
          IconButton(
            tooltip: '备份与恢复',
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BackupPage(state: widget.state),
              ),
            ),
          ),
          IconButton(
            tooltip: '锁定',
            icon: const Icon(Icons.lock),
            onPressed: () => widget.state.lock(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _sync,
        child: entries.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.key_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Center(child: Text('暂无条目，点击右下角新建')),
                ],
              )
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    leading: const Icon(Icons.password),
                    title: Text(entry.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(entry),
                    ),
                    onTap: () => _showSecret(entry),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

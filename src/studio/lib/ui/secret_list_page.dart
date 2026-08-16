import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/provider_client.dart';
import '../app_state.dart';
import 'backup_page.dart';
import 'secret_edit_page.dart';

/// 条目列表页：登录即用（服务端加密方案，无客户端密钥）。
///
/// 设计（docs/index.md 4.2）：登录后拉取全部条目（明文），
/// 点击条目查看/复制、新建/编辑、备份恢复均直接可用。
class SecretListPage extends StatefulWidget {
  const SecretListPage({super.key, required this.state});

  final AppState state;

  @override
  State<SecretListPage> createState() => _SecretListPageState();
}

class _SecretListPageState extends State<SecretListPage> {
  Future<void> _sync() async {
    try {
      await widget.state.refresh();
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

  Future<void> _showSecret(SecretItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SelectableText(item.secret),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: item.secret));
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
  }

  Future<void> _delete(SecretItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${item.name}」？'),
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
      await widget.state.client.delete(item.id);
      widget.state.cache.remove(item.id);
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

  Future<void> _openEdit([SecretItem? item]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SecretEditPage(state: widget.state, existing: item),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.state.cache.all.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的密码'),
        actions: [
          IconButton(
            tooltip: '备份与恢复',
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BackupPage(state: widget.state)),
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
                  final item = entries[index];
                  return ListTile(
                    leading: const Icon(Icons.password),
                    title: Text(item.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(item),
                    ),
                    onTap: () => _showSecret(item),
                    onLongPress: () => _openEdit(item),
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

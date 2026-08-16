import 'package:flutter/material.dart';

import '../api/provider_client.dart';
import '../app_state.dart';

/// 条目编辑页：新建/编辑机密条目（服务端加密方案，登录即用）。
///
/// 设计（docs/index.md 4.1）：name/secret 明文提交，服务端 MASTER_KEY 加密落盘。
class SecretEditPage extends StatefulWidget {
  const SecretEditPage({super.key, required this.state, this.existing});

  final AppState state;
  final SecretItem? existing;

  @override
  State<SecretEditPage> createState() => _SecretEditPageState();
}

class _SecretEditPageState extends State<SecretEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _secret;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _secret = TextEditingController(text: widget.existing?.secret ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final now = DateTime.now().toUtc();
      // 新建时 id 为空：由服务端生成（客户端不感知 UUID）
      final item = SecretItem(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        secret: _secret.text,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.existing == null) {
        final created = await widget.state.client.create(item);
        widget.state.cache.put(created);
      } else {
        await widget.state.client.update(item);
        widget.state.cache.put(item);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '新建条目' : '编辑条目'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '名称',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _secret,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

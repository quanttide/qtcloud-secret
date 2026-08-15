import 'package:flutter/material.dart';

import '../app_state.dart';
import '../crypto/envelope.dart';
import '../crypto/key_derivation.dart';

/// 条目编辑页：新建/编辑密码条目。
///
/// 设计（docs/index.md 4.1）：明文仅在内存——保存时随机 salt/nonce
/// 加密为信封后经 provider API 上传，明文不落盘。
class SecretEditPage extends StatefulWidget {
  const SecretEditPage({super.key, required this.state, this.existing});

  final AppState state;
  final SecretListEntry? existing;

  @override
  State<SecretEditPage> createState() => _SecretEditPageState();
}

class _SecretEditPageState extends State<SecretEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _password;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
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
      final (master, recovery) = widget.state.keyMaterial;
      final cipher = EnvelopeCipher(deriveKey: const KeyDerivation().deriveKey);
      final payload = await cipher.encrypt(
        masterPassword: master,
        recoveryCode: recovery,
        plaintext: _password.text,
      );

      final now = DateTime.now().toUtc();
      final envelope = Envelope(
        id: widget.existing?.id ??
            '${now.microsecondsSinceEpoch.toRadixString(16).padLeft(12, '0')}-'
                '0000-4000-8000-${now.millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0')}',
        name: _name.text.trim(),
        createdAt: widget.existing == null
            ? now
            : widget.state.cache.byId(widget.existing!.id)?.createdAt ?? now,
        updatedAt: now,
        encrypted: payload,
      );

      if (widget.existing == null) {
        await widget.state.client.create(envelope);
      } else {
        await widget.state.client.update(envelope);
      }
      widget.state.cache.put(envelope);
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
                controller: _password,
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

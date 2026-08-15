import 'package:flutter/material.dart';

import '../app_state.dart';
import 'secret_list_page.dart';

/// 解锁页：登录（qtcloud-auth）+ 主密码 + 恢复码。
///
/// 设计（docs/index.md 4.2）：解锁即派生密钥并全量同步；
/// 密钥材料只存在于 AppState 内存，锁定即清除。
class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key, required this.state});

  final AppState state;

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final _formKey = GlobalKey<FormState>();
  final _authUrl = TextEditingController(text: AppConfig.authBaseUrl);
  final _providerUrl = TextEditingController(text: AppConfig.providerBaseUrl);
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _masterPassword = TextEditingController();
  final _recoveryCode = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _authUrl.dispose();
    _providerUrl.dispose();
    _username.dispose();
    _password.dispose();
    _masterPassword.dispose();
    _recoveryCode.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.state.unlock(
        authBaseUrl: _authUrl.text.trim(),
        providerBaseUrl: _providerUrl.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        masterPassword: _masterPassword.text,
        recoveryCode: _recoveryCode.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SecretListPage(state: widget.state),
          ),
        );
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
      appBar: AppBar(title: const Text('量潮密码云')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 56),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _authUrl,
                    decoration: const InputDecoration(
                      labelText: '认证服务地址（qtcloud-auth）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _providerUrl,
                    decoration: const InputDecoration(
                      labelText: '密码云服务地址（provider）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: '账号',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '请输入账号' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '账号密码',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '请输入账号密码' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _masterPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '主密码（本地解密，永不传输）',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 8) ? '主密码至少 8 位' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _recoveryCode,
                    decoration: const InputDecoration(
                      labelText: '恢复码（Emergency Kit）',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入恢复码' : null,
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
                    onPressed: _busy ? null : _unlock,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('解锁'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '提示：主密码与恢复码仅在本机使用，服务端无法读取你的数据；'
                    '忘记主密码且丢失恢复码将无法恢复数据。',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 解锁页（模态）：主密码 + 恢复码（本地密钥派生，验证「你有没有密钥」）。
//
// 与登录页分离（docs/index.md 4.2）：登录（账号密码）只获取会话并展示
// 资源清单（明文元数据）；本页只在需要解密/加密的操作（查看条目、
// 新建编辑、恢复导入）时由列表页按需弹出——成功后 pop(true) 返回。
// 密钥材料只存在于 AppState 内存，锁定即清除。
// 服务端地址为编译期配置，UI 不暴露任何地址入口。
import 'package:flutter/material.dart';

import '../app_state.dart';

class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key, required this.state});

  final AppState state;

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final _formKey = GlobalKey<FormState>();
  final _masterPassword = TextEditingController();
  final _recoveryCode = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
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
        masterPassword: _masterPassword.text,
        recoveryCode: _recoveryCode.text.trim(),
      );
      if (mounted) {
        // 解锁成功：返回 true，由调用方（列表页）继续原操作
        Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('解锁保险库')),
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
                  const Icon(Icons.key_outlined, size: 56),
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                    '主密码与恢复码仅在本机使用，服务端无法读取你的数据；'
                    '忘记主密码且丢失恢复码将无法恢复数据。',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: widget.state.logout,
                    child: const Text('切换账号'),
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

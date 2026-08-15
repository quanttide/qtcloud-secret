// 设置页：密钥管理（恢复码生成器 + 修改密钥）。
//
// 设计（docs/index.md 4.2 / docs/user-guide/backup-recovery.md）：
// - 恢复码是零知识下唯一恢复通道：提供 CSPRNG 生成器 + 复制，
//   用户离线保存（打印/加密文件），与主密码分开保管
// - 修改密钥 = 重加密全部条目：旧密钥解密 → 新密钥加密 → 批量上传；
//   完成后旧密钥立即失效（不可逆，操作前明确警告）
// - 修改密钥需已解锁（旧密钥在手）；未解锁时仅恢复码生成器可用
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../crypto/emergency_kit.dart';
import '../crypto/envelope.dart';
import '../crypto/key_derivation.dart';
import 'unlock_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _newMaster;
  late final TextEditingController _newRecovery;
  String? _generatedCode;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _newMaster = TextEditingController();
    _newRecovery = TextEditingController();
  }

  @override
  void dispose() {
    _newMaster.dispose();
    _newRecovery.dispose();
    super.dispose();
  }

  void _generateRecoveryCode() {
    final code = EmergencyKit.generate('').recoveryCode;
    setState(() {
      _generatedCode = code;
      _newRecovery.text = code;
    });
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  Future<void> _ensureUnlocked() async {
    if (widget.state.unlocked) {
      return;
    }
    if (!mounted) {
      return;
    }
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UnlockPage(state: widget.state)),
    );
    if (ok == true && mounted) {
      setState(() {});
    }
  }

  /// 修改密钥：旧密钥解密 → 新密钥重加密 → 批量上传 → 更新会话密钥。
  Future<void> _applyRekey() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改密钥并重加密全部条目？'),
        content: const Text(
          '全部条目将用新密钥重新加密并上传，此操作不可逆：\n'
          '· 旧主密码/恢复码立即失效\n'
          '· 网络中断可能导致部分条目未更新（可重试）\n'
          '· 请先确认已保存新恢复码（Emergency Kit）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认修改'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final (oldMaster, oldRecovery) = widget.state.keyMaterial;
      final newMaster = _newMaster.text;
      final newRecovery = _newRecovery.text.trim();
      final cipher =
          EnvelopeCipher(deriveKey: const KeyDerivation().deriveKey);
      final now = DateTime.now().toUtc();

      var count = 0;
      for (final e in widget.state.cache.all) {
        final plain = await widget.state.sync.decrypt(
          e.id,
          oldMaster,
          oldRecovery,
        );
        final payload = await cipher.encrypt(
          masterPassword: newMaster,
          recoveryCode: newRecovery,
          plaintext: plain,
        );
        final newEnv = Envelope(
          id: e.id,
          name: e.name,
          createdAt: e.createdAt,
          updatedAt: now,
          encrypted: payload,
        );
        await widget.state.client.update(newEnv);
        widget.state.cache.put(newEnv);
        count++;
      }

      widget.state.setKeyMaterial(newMaster, newRecovery);
      _newMaster.clear();
      setState(() {
        _generatedCode = null;
        _message = '密钥已更新：$count 个条目已用新密钥重新加密';
        _messageIsError = false;
      });
    } catch (e) {
      setState(() {
        _message = '重加密失败：$e（可重试，已更新的条目以新密钥为准）';
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
    final unlocked = widget.state.unlocked;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 恢复码生成器（任何状态下可用） ──
            const Text('恢复码生成器（Emergency Kit）',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              '恢复码与主密码一起参与本地密钥派生（零知识双因子）；'
              '生成后请立即离线保存（打印/加密文件），与主密码分开保管。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_generatedCode != null) ...[
              SelectableText(
                _generatedCode!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => _copy(_generatedCode!),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('复制恢复码'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _busy ? null : _generateRecoveryCode,
              icon: const Icon(Icons.refresh),
              label: Text(_generatedCode == null ? '生成恢复码' : '重新生成'),
            ),
            const Divider(height: 32),

            // ── 修改密钥（需已解锁） ──
            const Text('修改密钥', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (!unlocked)
              const Text(
                '当前未解锁：修改密钥需先解锁（旧密钥在手才能重加密）。'
                '点击下方「去解锁」后即可修改。',
                style: TextStyle(fontSize: 12),
              )
            else
              const Text(
                '修改后将用新密钥重加密全部条目并上传，旧密钥立即失效（不可逆）。',
                style: TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 12),
            if (!unlocked)
              OutlinedButton(
                onPressed: _busy ? null : _ensureUnlocked,
                child: const Text('去解锁'),
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _newMaster,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '新主密码（≥8 位）',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 8) ? '主密码至少 8 位' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _newRecovery,
                      decoration: const InputDecoration(
                        labelText: '新恢复码（可点上方生成）',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入恢复码' : null,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _applyRekey,
                      icon: const Icon(Icons.key),
                      label: const Text('应用新密钥并重加密全部条目'),
                    ),
                  ],
                ),
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
          ],
        ),
      ),
    );
  }
}

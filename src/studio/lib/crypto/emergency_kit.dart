// 紧急恢复套件（Emergency Kit）。
//
// 设计（docs/user-guide/backup-recovery.md）：
// - 恢复码与主密码一起派生（Argon2 secret），是零知识下唯一恢复通道
// - 注册时强制引导生成：打印纸质 / 加密文件保存
// - 恢复码丢失 = 数据永久丢失，产品必须明示
import 'dart:math';

class EmergencyKit {
  const EmergencyKit({
    required this.username,
    required this.recoveryCode,
  });

  final String username;
  final String recoveryCode;

  /// 生成 Emergency Kit（CSPRNG 恢复码，20 字符 base32 风格）。
  factory EmergencyKit.generate(String username) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 去除易混淆字符
    final rng = Random.secure();
    final code = List.generate(
      20,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
    return EmergencyKit(username: username, recoveryCode: code);
  }

  /// 可打印的 Kit 文本（用户离线保存）。
  String toText() => '''
量潮密码云 - 紧急恢复套件（Emergency Kit）
=========================================
账户：$username
恢复码：$recoveryCode

使用说明：
1. 恢复码与主密码一起用于解密你的数据，请与主密码分开保管
2. 主密码忘记时，凭恢复码 + 记得的主密码残片可恢复
3. 恢复码丢失 = 数据永久丢失，无法找回
4. 任何索要恢复码的"客服"都是诈骗
''';
}

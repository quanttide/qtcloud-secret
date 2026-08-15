// 密钥派生（Argon2id + 恢复码双因子）。
//
// 设计（docs/dev-guide/security.md 3.2/3.4）：
// - 派生密钥不存在于任何介质：每次解锁现派生、用完即弃
// - salt 随机生成，随密文信封存储（明文，不怕泄露）
// - 恢复码作为 Argon2 secret 参与派生：即使主密码被键盘记录器窃取，
//   攻击者仍缺恢复码无法派生密钥；用户忘记主密码时凭恢复码恢复
// - 高成本参数（迭代/内存）是抗暴力破解的关键
import 'dart:math';
import 'dart:typed_data';

import 'package:argon2/argon2.dart';

class KeyDerivation {
  const KeyDerivation();

  /// Argon2id 参数：3 轮迭代，2^16 KiB（64 MiB）内存，4 并行道。
  /// 移动端可调低 memoryPowerOf2（如 15 = 32 MiB），勿低于 14。
  static const int iterations = 3;
  static const int memoryPowerOf2 = 16;
  static const int parallelism = 4;
  static const int keyLength = 32; // AES-256

  /// 派生 32 字节加密密钥。
  ///
  /// [masterPassword] 主密码；[recoveryCode] 恢复码（Emergency Kit，
  /// 作为 Argon2 secret 参与派生）；[salt] 随机盐（随信封存储）。
  Uint8List deriveKey(
    String masterPassword,
    String recoveryCode,
    Uint8List salt,
  ) {
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      secret: Uint8List.fromList(recoveryCode.codeUnits),
      iterations: iterations,
      memoryPowerOf2: memoryPowerOf2,
      lanes: parallelism,
      version: Argon2Parameters.ARGON2_VERSION_13,
    );
    final generator = Argon2BytesGenerator();
    generator.init(parameters);
    final passwordBytes = parameters.converter.convert(masterPassword);
    final out = Uint8List(keyLength);
    generator.generateBytes(passwordBytes, out);
    return out;
  }

  /// 生成随机盐（CSPRNG，16 字节）。
  Uint8List generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => rng.nextInt(256)),
    );
  }
}

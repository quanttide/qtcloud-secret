// 密钥派生（Argon2id）。
//
// 设计（docs/dev-guide/security.md 3.2）：
// - 派生密钥不存在于任何介质：每次解锁现派生、用完即弃
// - salt 随机生成，随密文信封存储（明文，不怕泄露）
// - 高成本参数（迭代/内存）是抗暴力破解的关键
//
// TODO: 引入 argon2 包实现：
//   - deriveKey(masterPassword, salt) → 派生密钥
//   - generateSalt() → CSPRNG 随机盐
library;

class KeyDerivation {
  const KeyDerivation();

  /// 派生加密密钥（当前为占位，待接入 argon2 实现）。
  List<int> derive(List<int> masterPassword, List<int> salt) {
    throw UnimplementedError('TODO: Argon2id 派生实现');
  }

  /// 生成随机盐。
  List<int> generateSalt() {
    throw UnimplementedError('TODO: CSPRNG 盐生成');
  }
}

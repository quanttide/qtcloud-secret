// 密文信封加解密（AES-256-GCM）。
//
// 对齐 provider 数据模型（src/provider/internal/model/envelope.go）：
//   明文元数据（id/name/时间戳）+ encrypted 负载（algorithm/kdf/kdfSalt/nonce/ciphertext）
// 每次加密随机生成 nonce 与 salt，同一条目两次加密产生不同密文。
//
// TODO: 引入 cryptography 包实现 encrypt/decrypt；错误处理（GCM 认证失败 = 密文被篡改）。
library;

class Envelope {
  const Envelope({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.encrypted,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> encrypted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'encrypted': encrypted,
      };
}

// 密文信封：AES-256-GCM 加解密 + 序列化。
//
// 对齐 provider 数据模型（src/provider/internal/model/envelope.go 与
// docs/dev-guide/model.md）：明文元数据（id/name/时间戳）+ encrypted 负载。
// GCM 认证标签拼接在 ciphertext 尾部（16 字节），解密时校验——
// 密文被篡改会在解密时立即失败。
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'key_derivation.dart';

/// 加密负载（与 provider 信封 schema 一致）。
class EncryptedPayload {
  const EncryptedPayload({
    required this.algorithm,
    required this.kdf,
    required this.kdfSalt,
    required this.nonce,
    required this.ciphertext,
  });

  final String algorithm;
  final String kdf;
  final String kdfSalt; // base64
  final String nonce; // base64
  final String ciphertext; // base64（含 GCM tag）

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) =>
      EncryptedPayload(
        algorithm: json['algorithm'] as String,
        kdf: json['kdf'] as String,
        kdfSalt: json['kdfSalt'] as String,
        nonce: json['nonce'] as String,
        ciphertext: json['ciphertext'] as String,
      );

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm,
        'kdf': kdf,
        'kdfSalt': kdfSalt,
        'nonce': nonce,
        'ciphertext': ciphertext,
      };
}

/// 密文信封：明文元数据 + 加密负载。
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
  final EncryptedPayload encrypted;

  factory Envelope.fromJson(Map<String, dynamic> json) => Envelope(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        encrypted: EncryptedPayload.fromJson(json['encrypted'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'encrypted': encrypted.toJson(),
      };
}

/// 信封加解密引擎（AES-256-GCM）。
class EnvelopeCipher {
  const EnvelopeCipher({required this.deriveKey});

  /// 派生函数注入（由 KeyDerivation 提供），便于测试替换。
  final Uint8List Function(String masterPassword, String recoveryCode, Uint8List salt)
      deriveKey;

  static final _algorithm = AesGcm.with256bits();

  /// 加密明文密码为信封负载。
  ///
  /// 每次加密随机生成 salt 与 nonce——同一条目两次加密产生不同密文。
  Future<EncryptedPayload> encrypt({
    required String masterPassword,
    required String recoveryCode,
    required String plaintext,
  }) async {
    final derivation = KeyDerivation();
    final salt = derivation.generateSalt();
    final key = deriveKey(masterPassword, recoveryCode, salt);
    final secretBox = await _algorithm.encrypt(
      Uint8List.fromList(utf8.encode(plaintext)),
      secretKey: SecretKey(key),
    );
    return EncryptedPayload(
      algorithm: 'AES-256-GCM',
      kdf: 'Argon2id',
      kdfSalt: base64Encode(salt),
      nonce: base64Encode(secretBox.nonce),
      ciphertext: base64Encode([...secretBox.cipherText, ...secretBox.mac.bytes]),
    );
  }

  /// 解密信封负载为明文密码。
  ///
  /// GCM 认证失败（密文被篡改/密钥错误）抛出异常。
  Future<String> decrypt({
    required String masterPassword,
    required String recoveryCode,
    required EncryptedPayload payload,
  }) async {
    final salt = base64Decode(payload.kdfSalt);
    final key = deriveKey(masterPassword, recoveryCode, salt);
    final raw = base64Decode(payload.ciphertext);
    final secretBox = SecretBox(
      raw.sublist(0, raw.length - 16),
      nonce: base64Decode(payload.nonce),
      mac: Mac(Uint8List.fromList(raw.sublist(raw.length - 16))),
    );
    final clear = await _algorithm.decrypt(secretBox, secretKey: SecretKey(key));
    return utf8.decode(clear);
  }
}

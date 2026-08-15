// crypto 层单元测试：派生、加解密往返、篡改检测、Emergency Kit。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:studio/crypto/emergency_kit.dart';
import 'package:studio/crypto/envelope.dart';
import 'package:studio/crypto/key_derivation.dart';

void main() {
  const master = 'correct-horse-battery-staple';
  const recovery = 'ABCDE-FGHJK-LMNPQ-RSTUV';
  const plaintext = 'P@ssw0rd-2026!';
  final derivation = const KeyDerivation();
  final cipher = EnvelopeCipher(deriveKey: derivation.deriveKey);

  group('KeyDerivation', () {
    test('派生密钥长度为 32 字节', () {
      final key = derivation.deriveKey(master, recovery, derivation.generateSalt());
      expect(key.length, 32);
    });

    test('相同输入派生相同密钥', () {
      final salt = derivation.generateSalt();
      final k1 = derivation.deriveKey(master, recovery, salt);
      final k2 = derivation.deriveKey(master, recovery, salt);
      expect(k1, k2);
    });

    test('不同盐派生不同密钥', () {
      final k1 = derivation.deriveKey(master, recovery, derivation.generateSalt());
      final k2 = derivation.deriveKey(master, recovery, derivation.generateSalt());
      expect(k1, isNot(k2));
    });

    test('错误恢复码派生不同密钥（双因子生效）', () {
      final salt = derivation.generateSalt();
      final k1 = derivation.deriveKey(master, recovery, salt);
      final k2 = derivation.deriveKey(master, 'WRONG-CODE', salt);
      expect(k1, isNot(k2));
    });

    test('派生结果与固定向量一致（数据兼容性契约）', () {
      // 该向量由 argon2 1.0.1（ffi）与 argon2_web 0.3.0 双实现逐字节
      // 对比一致后固化：任何参数/算法变更不得改变派生结果，
      // 否则既有密文将无法解密（零知识下无法迁移）。
      // 输入：master='correct-horse-battery-staple'（UTF-8），
      //       recovery='ABCDE-FGHJK-LMNPQ-RSTUV'（secret 原始字节），
      //       salt=[i*7+3 for i in 0..15]
      final salt = Uint8List.fromList(
        List<int>.generate(16, (i) => i * 7 + 3),
      );
      final key = derivation.deriveKey(master, recovery, salt);
      expect(
        base64Encode(key),
        'Vg/Dy9lZcfsJgCc5WzH0QlMd75kvG9lIAiGonKcU2H8=',
      );
    });
  });

  group('EnvelopeCipher', () {
    test('加解密往返一致', () async {
      final payload = await cipher.encrypt(
        masterPassword: master,
        recoveryCode: recovery,
        plaintext: plaintext,
      );
      expect(payload.algorithm, 'AES-256-GCM');
      expect(payload.kdf, 'Argon2id');
      final decrypted = await cipher.decrypt(
        masterPassword: master,
        recoveryCode: recovery,
        payload: payload,
      );
      expect(decrypted, plaintext);
    });

    test('同一条目两次加密产生不同密文（随机 nonce/salt）', () async {
      final p1 = await cipher.encrypt(
        masterPassword: master,
        recoveryCode: recovery,
        plaintext: plaintext,
      );
      final p2 = await cipher.encrypt(
        masterPassword: master,
        recoveryCode: recovery,
        plaintext: plaintext,
      );
      expect(p1.ciphertext, isNot(p2.ciphertext));
      expect(p1.nonce, isNot(p2.nonce));
      expect(p1.kdfSalt, isNot(p2.kdfSalt));
    });

    test('密文被篡改时解密失败（GCM 认证）', () async {
      final payload = await cipher.encrypt(
        masterPassword: master,
        recoveryCode: recovery,
        plaintext: plaintext,
      );
      final raw = base64Decode(payload.ciphertext);
      raw[0] ^= 0x01; // 翻转一个字节
      final tampered = EncryptedPayload(
        algorithm: payload.algorithm,
        kdf: payload.kdf,
        kdfSalt: payload.kdfSalt,
        nonce: payload.nonce,
        ciphertext: base64Encode(raw),
      );
      expect(
        () => cipher.decrypt(
          masterPassword: master,
          recoveryCode: recovery,
          payload: tampered,
        ),
        throwsA(anything),
      );
    });

    test('错误主密码解密失败', () async {
      final payload = await cipher.encrypt(
        masterPassword: master,
        recoveryCode: recovery,
        plaintext: plaintext,
      );
      expect(
        () => cipher.decrypt(
          masterPassword: 'wrong-password',
          recoveryCode: recovery,
          payload: payload,
        ),
        throwsA(anything),
      );
    });

    test('信封 JSON 序列化与解析往返一致', () async {
      final payload = await cipher.encrypt(
        masterPassword: master,
        recoveryCode: recovery,
        plaintext: plaintext,
      );
      final envelope = Envelope(
        id: 'a1b2c3d4-0000-4000-8000-000000000001',
        name: 'GitHub',
        createdAt: DateTime.utc(2026, 8, 16),
        updatedAt: DateTime.utc(2026, 8, 16),
        encrypted: payload,
      );
      final json = jsonEncode(envelope.toJson());
      final parsed = Envelope.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(parsed.id, envelope.id);
      expect(parsed.name, envelope.name);
      expect(parsed.encrypted.ciphertext, payload.ciphertext);
      final decrypted = await cipher.decrypt(
        masterPassword: master,
        recoveryCode: recovery,
        payload: parsed.encrypted,
      );
      expect(decrypted, plaintext);
    });
  });

  group('EmergencyKit', () {
    test('生成恢复码为 20 字符且唯一', () {
      final kit = EmergencyKit.generate('user@quanttide.com');
      expect(kit.username, 'user@quanttide.com');
      expect(kit.recoveryCode.length, 20);
      final kit2 = EmergencyKit.generate('user@quanttide.com');
      expect(kit.recoveryCode, isNot(kit2.recoveryCode));
    });

    test('toText 包含使用说明与恢复码', () {
      final kit = EmergencyKit(username: 'u', recoveryCode: 'CODE1234567890');
      final text = kit.toText();
      expect(text, contains('CODE1234567890'));
      expect(text, contains('恢复码丢失 = 数据永久丢失'));
    });
  });

  test('派生密钥可清除（Uint8List 归零）', () {
    final salt = derivation.generateSalt();
    final key = derivation.deriveKey(master, recovery, salt);
    key.fillRange(0, key.length, 0);
    expect(key.every((b) => b == 0), isTrue);
  });
}

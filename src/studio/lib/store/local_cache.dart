// 本地缓存与索引：密文信封缓存 + 内存明文索引。
//
// 设计（docs/index.md 5）：密文缓存（含元数据），明文索引仅内存——
// 解锁后从密文派生，锁定时全部清除；明文不落盘。
import '../crypto/envelope.dart';

/// 会话级缓存：密文信封 + 解锁后的明文索引。
class LocalCache {
  LocalCache();

  /// 密文信封缓存（id → envelope，含元数据）。
  final Map<String, Envelope> _envelopes = {};

  /// 解锁后建立的明文索引（id → 明文密码）。
  /// 仅存在于内存，锁定时清除；不落盘。
  final Map<String, String> _plaintextIndex = {};

  bool get isEmpty => _envelopes.isEmpty;

  List<Envelope> get all => _envelopes.values.toList();

  Envelope? byId(String id) => _envelopes[id];

  String? plaintextOf(String id) => _plaintextIndex[id];

  void put(Envelope envelope) => _envelopes[envelope.id] = envelope;

  void putPlaintext(String id, String plaintext) =>
      _plaintextIndex[id] = plaintext;

  void remove(String id) {
    _envelopes.remove(id);
    _plaintextIndex.remove(id);
  }

  /// 锁定：清除全部缓存与明文索引（内存清零）。
  void clear() {
    _envelopes.clear();
    _plaintextIndex.clear();
  }
}

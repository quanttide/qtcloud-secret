// 本地缓存与索引：密文落盘、明文索引仅内存。
//
// 设计（docs/index.md 5）：密文缓存 + 元数据索引；明文索引不落盘，
// 解锁后从密文派生。TODO: 接入 sqflite/drift。
library;

class LocalCache {
  const LocalCache();

  /// 保存密文信封到本地缓存。
  void putEnvelope(Object envelope) {
    throw UnimplementedError('TODO: 密文缓存实现');
  }
}

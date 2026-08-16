// 本地缓存：会话级明文条目缓存（服务端加密方案，无客户端密钥）。
//
// 设计：登录后从服务端拉取全部条目（服务端解密返回明文），
// 内存缓存供列表/查看使用；锁定/退出时全部清除（明文不落盘）。
import '../api/provider_client.dart';

/// 会话级缓存：明文条目。
class LocalCache {
  LocalCache();

  /// 条目缓存（id → SecretItem 明文）。
  final Map<String, SecretItem> _items = {};

  bool get isEmpty => _items.isEmpty;

  List<SecretItem> get all => _items.values.toList();

  SecretItem? byId(String id) => _items[id];

  void put(SecretItem item) => _items[item.id] = item;

  void remove(String id) => _items.remove(id);

  /// 全量同步：拉取清单 + 拉取条目（含 name/secret 明文）→ 更新缓存。
  Future<int> syncAll(ProviderClient client) async {
    final metas = await client.list();
    final remoteIds = <String>{};
    for (final meta in metas) {
      remoteIds.add(meta.id);
      final local = _items[meta.id];
      if (local == null || local.updatedAt.isBefore(meta.updatedAt)) {
        _items[meta.id] = await client.get(meta.id);
      }
    }
    // 本地有而远端无 → 已删除
    final toRemove = _items.keys.where((id) => !remoteIds.contains(id)).toList();
    for (final id in toRemove) {
      _items.remove(id);
    }
    return metas.length;
  }

  /// 锁定/退出：清除全部缓存（明文不落盘）。
  void clearAll() => _items.clear();
}

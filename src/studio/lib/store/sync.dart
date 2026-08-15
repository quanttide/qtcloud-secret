// 同步引擎：全量拉取清单 + 差异合并。
//
// 设计（docs/index.md 4.2）：小数据量下全量同步即可——
// GET /secrets 清单 → 与本地缓存比对（id + updatedAt）→
// 差异拉取密文 → 解密建立明文索引。sync_token 为团队版增量预留。
import '../api/provider_client.dart';
import '../crypto/envelope.dart';
import '../crypto/key_derivation.dart';
import 'local_cache.dart';

class SyncEngine {
  SyncEngine({required this.client, required this.cache});

  final ProviderClient client;
  final LocalCache cache;

  final EnvelopeCipher _cipher =
      EnvelopeCipher(deriveKey: const KeyDerivation().deriveKey);

  /// 执行一次全量同步，返回同步的条目数。
  Future<int> syncAll({
    required String masterPassword,
    required String recoveryCode,
  }) async {
    final metas = await client.list();
    final remoteIds = <String>{};

    for (final meta in metas) {
      remoteIds.add(meta.id);
      final local = cache.byId(meta.id);
      // 新增或远端更新（updatedAt 更新）时拉取
      if (local == null || local.updatedAt.isBefore(meta.updatedAt)) {
        final envelope = await client.get(meta.id);
        cache.put(envelope);
        await _decryptIntoIndex(envelope, masterPassword, recoveryCode);
      } else {
        // 本地已有且未过期：确保明文索引存在
        if (cache.plaintextOf(meta.id) == null) {
          await _decryptIntoIndex(local, masterPassword, recoveryCode);
        }
      }
    }

    // 本地有而远端无 → 已删除
    final toRemove = cache.all
        .map((e) => e.id)
        .where((id) => !remoteIds.contains(id))
        .toList();
    for (final id in toRemove) {
      cache.remove(id);
    }

    return metas.length;
  }

  Future<void> _decryptIntoIndex(
    Envelope envelope,
    String masterPassword,
    String recoveryCode,
  ) async {
    final plaintext = await _cipher.decrypt(
      masterPassword: masterPassword,
      recoveryCode: recoveryCode,
      payload: envelope.encrypted,
    );
    cache.putPlaintext(envelope.id, plaintext);
  }

  /// 解密单个条目（点击查看时兜底）。
  Future<String> decrypt(String id, String masterPassword, String recoveryCode) async {
    final cached = cache.plaintextOf(id);
    if (cached != null) {
      return cached;
    }
    final envelope = cache.byId(id);
    if (envelope == null) {
      throw StateError('条目不存在：$id');
    }
    final plaintext = await _cipher.decrypt(
      masterPassword: masterPassword,
      recoveryCode: recoveryCode,
      payload: envelope.encrypted,
    );
    cache.putPlaintext(id, plaintext);
    return plaintext;
  }
}

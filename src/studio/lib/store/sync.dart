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

  /// 同步清单元数据：拉取清单 + 差异拉取密文信封（不解密，无需密钥）。
  ///
  /// 设计：name 等元数据是信封明文字段，登录后即可展示资源清单；
  /// 仅密文负载需要密钥解密（见 syncAll）。登录后调用本方法，列表立即可见。
  Future<int> syncMetas() async {
    final metas = await client.list();
    final remoteIds = <String>{};

    for (final meta in metas) {
      remoteIds.add(meta.id);
      final local = cache.byId(meta.id);
      // 新增或远端更新（updatedAt 更新）时拉取信封（不解密）
      if (local == null || local.updatedAt.isBefore(meta.updatedAt)) {
        cache.put(await client.get(meta.id));
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

  /// 执行一次全量同步（元数据 + 解密建立明文索引），返回同步的条目数。
  Future<int> syncAll({
    required String masterPassword,
    required String recoveryCode,
  }) async {
    final n = await syncMetas();

    // 解密所有缓存信封 → 明文索引（缺则解）
    for (final envelope in cache.all) {
      if (cache.plaintextOf(envelope.id) == null) {
        await _decryptIntoIndex(envelope, masterPassword, recoveryCode);
      }
    }

    return n;
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

// 同步：全量拉取密文清单 + 差异合并。
//
// 设计（docs/index.md 4.2）：小数据量下全量同步即可，
// 进入前台/手动刷新触发；sync_token 为团队版增量预留。
// TODO: 接入 ProviderClient + LocalCache 实现差异合并。
library;

class SyncEngine {
  const SyncEngine();

  /// 执行一次全量同步。
  Future<void> syncAll() async {
    throw UnimplementedError('TODO: 全量同步实现');
  }
}

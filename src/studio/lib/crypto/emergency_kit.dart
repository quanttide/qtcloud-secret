// 紧急恢复套件（Emergency Kit）。
//
// 设计（docs/user-guide/backup-recovery.md）：
// - 恢复码与主密码一起派生，是零知识下唯一恢复通道
// - 注册时强制引导生成：打印纸质 / 加密文件
// - 团队版扩展：Shamir 碎片（受托恢复）
//
// TODO: 恢复码生成（CSPRNG）、kit 解析/校验、导出模板。
library;

class EmergencyKit {
  const EmergencyKit({
    required this.username,
    required this.recoveryCode,
  });

  final String username;
  final String recoveryCode;
}

# qtcloud-secret

量潮机密云——1Password 的团队协作版（单团队、纯 OSS 存储阶段），机密管理覆盖密码、证件、密钥与敏感信息等所有需要同一套安全架构处理的对象。

- 架构设计：`docs/dev-guide/`（存储选型、传输架构、数据模型、零知识安全）
- 用户手册：`docs/user-guide/`
- 服务端：`src/provider/`（Go，FC 3.0 custom-container）
- 部署 IaC：`manifests/terraform/`（OSS 数据桶 + FC 应用服务）
- CI：`.github/workflows/deploy-provider.yml`（tag `provider/*` 触发部署）

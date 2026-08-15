# =============================================================================
# Studio Web 静态站点桶（secret.cloud.quanttide.com）
#
# 部署链路（.github/workflows/deploy-studio.yml）：
#   studio/* tag → Actions（flutter build web + ossutil cp）→ 本桶（静态网站模式）
#   → 阿里云 CDN（secret.cloud.quanttide.com，泛域名证书 *.quanttide.com）→ 用户浏览器
#
# 注意：
#   - 桶保持私有（RAM 用户无权限设公共读 ACL，阿里云禁止 RAM 用户开放公共读）；
#     CDN 域名配置时开启「私有 Bucket 回源」（回源鉴权），页面经 CDN 正常访问
#   - CDN 域名与 DNS（CNAME）首次需在阿里云控制台配置（泛域名证书已存在则可直接添加域名）
# =============================================================================

resource "alicloud_oss_bucket" "studio" {
  bucket            = "qtcloud-secret-studio"
  storage_class     = "Standard"
  resource_group_id = data.terraform_remote_state.platform.outputs.resource_group_id
  tags = {
    project     = var.project
    environment = var.environment
  }

  # 静态网站托管：index.html 为入口（Flutter Web SPA）
  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

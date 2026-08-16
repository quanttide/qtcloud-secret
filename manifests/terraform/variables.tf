variable "region" {
  description = "阿里云地域"
  type        = string
  default     = "cn-hangzhou"
}

variable "project" {
  description = "项目名（资源命名前缀）"
  type        = string
  default     = "qtcloud-secret"
}

variable "environment" {
  description = "环境：dev / prod"
  type        = string
  default     = "prod"
}

variable "oss_bucket_name" {
  description = "密文数据桶名（OSS 全局唯一；版本控制 + SSE-OSS，见 oss.tf）"
  type        = string
  default     = "qtcloud-secret-data"
}

variable "oss_version_retention_days" {
  description = "OSS 生命周期：非当前版本（历史版本）保留天数，超过后清理，防止版本膨胀"
  type        = number
  default     = 30
}

variable "image" {
  description = "FC 容器镜像。由 CI 注入（TF_VAR_image 拼接 secret ALIYUN_ACR_REGISTRY 的实例地址）或 terraform.tfvars 提供；实例地址属敏感信息不写默认值"
  type        = string
}

variable "fc_memory" {
  description = "FC 函数内存（MB）"
  type        = number
  default     = 512
}

variable "fc_timeout" {
  description = "FC 函数超时（秒）"
  type        = number
  default     = 60
}

variable "jwt_secret" {
  description = "JWT HS256 签名密钥（历史方案：与 qtcloud-auth 共享的 org secret JWT_SECRET）。仅 jwt_public_key 未配置时生效（本地/旧环境回落）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_public_key" {
  description = "qtcloud-auth JWT RS256 验签公钥（base64(PEM) 单行，与 auth 的 JWT_PRIVATE_KEY 注入方式对齐）。由 CI 从 org secret JWT_PRIVATE_KEY 派生注入，不入库"
  type        = string
  sensitive   = true
  default     = ""
}

variable "master_key" {
  description = "服务端主密钥（base64 32 字节，AES-256-GCM 加密 secret 字段；运维资产，丢失可重置重加密）。通过 TF_VAR_master_key 注入（org secret MASTER_KEY），不入库"
  type        = string
  sensitive   = true
  default     = ""
}

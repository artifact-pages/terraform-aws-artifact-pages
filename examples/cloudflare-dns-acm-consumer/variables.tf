variable "aws_region" {
  description = "Region for the private S3 bucket and IAM roles."
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "Unique S3 bucket name for this deployment."
  type        = string
  default     = "artifact-pages-aws-domain-example-0001"
}

variable "preview_retention_days" {
  description = "Whole-day lifecycle retention required by the current CLI/module contract."
  type        = number
  default     = 1
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN in the AWS account."
  type        = string
  default     = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
}

variable "admin_github_subjects" {
  description = "Exact GitHub OIDC subjects allowed to assume the admin role."
  type        = list(string)
  default     = ["repo:example/admin:ref:refs/heads/main"]
}

variable "cloudflare_zone_id" {
  description = "Existing Cloudflare zone ID for artifact-pages.dev."
  type        = string
  default     = "11111111111111111111111111111111"
}

variable "cloudflare_zone_name" {
  description = "Existing Cloudflare zone name."
  type        = string
  default     = "artifact-pages.dev"
}

variable "aws_hostname" {
  description = "AWS verification hostname below the Cloudflare zone."
  type        = string
  default     = "aws.artifact-pages.dev"
}

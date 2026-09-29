variable "aws_region" {
  description = "Region for the private S3 bucket and IAM roles."
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "Optional S3 bucket name override; omit to use the module's deterministic AWS provider account-and-region default."
  type        = string
  default     = null
}

variable "preview_retention_days" {
  description = "Whole-day preview retention enforced by S3 lifecycle; this stays in Terraform and is not included in the CLI deployment config."
  type        = number
  default     = 1
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN in the AWS provider target account."
  type        = string
  default     = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
}

variable "admin_github_subjects" {
  description = "Exact GitHub OIDC subjects allowed to assume the admin role."
  type        = list(string)
  default     = ["repo:example/admin:ref:refs/heads/main"]
}

variable "cloudflare_zone_id" {
  description = "Existing Cloudflare zone ID."
  type        = string
  default     = "11111111111111111111111111111111"
}

variable "cloudflare_zone_name" {
  description = "Existing Cloudflare zone name."
  type        = string
  default     = "example.com"
}

variable "aws_hostname" {
  description = "AWS verification hostname below the Cloudflare zone."
  type        = string
  default     = "aws.example.com"
}

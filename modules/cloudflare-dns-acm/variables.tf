variable "name_prefix" {
  description = "Prefix used for named AWS resources."
  type        = string
  default     = "artifact-pages"
}

variable "aws_region" {
  description = "Region for the private S3 bucket and IAM roles; must match the caller's default AWS provider region."
  type        = string
}

variable "bucket_name" {
  description = "Optional S3 bucket name override. Defaults to artifact-pages-<AWS provider account ID>-<AWS region>."
  type        = string
  default     = null
}

variable "preview_retention_days" {
  description = "Provider-managed lifetime in whole days for all objects under _previews/."
  type        = number

  validation {
    condition     = var.preview_retention_days >= 1 && var.preview_retention_days <= 36500 && floor(var.preview_retention_days) == var.preview_retention_days
    error_message = "preview_retention_days must be a whole number from 1 to 36500."
  }
}

variable "github_oidc_provider_arn" {
  description = "ARN of the existing GitHub Actions OIDC provider; its account ID must match the AWS provider target account."
  type        = string
}

variable "admin_github_subjects" {
  description = "Exact GitHub OIDC sub claims allowed to assume the admin role."
  type        = list(string)

  validation {
    condition     = length(var.admin_github_subjects) > 0 && alltrue([for subject in var.admin_github_subjects : startswith(subject, "repo:")])
    error_message = "admin_github_subjects must contain one or more repo:... GitHub OIDC subjects."
  }
}

variable "satellite_github_subjects" {
  description = "Map of site IDs to exact GitHub OIDC sub claims allowed to publish that site."
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([
      for site_id, subjects in var.satellite_github_subjects :
      can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", site_id)) && site_id != "assets" && length(subjects) > 0 && alltrue([for subject in subjects : startswith(subject, "repo:")])
    ])
    error_message = "Satellite map keys must be non-reserved site IDs and every value must contain repo:... OIDC subjects."
  }
}

variable "cloudflare_domain" {
  description = "Existing Cloudflare zone and one hostname beneath it. The hostname must be a subdomain so this module never manages the apex."
  type = object({
    zone_id   = string
    zone_name = string
    hostname  = string
  })

  validation {
    condition = (
      can(regex("^[0-9a-fA-F]{32}$", var.cloudflare_domain.zone_id)) &&
      length(var.cloudflare_domain.zone_name) <= 253 &&
      length(split(".", var.cloudflare_domain.zone_name)) >= 2 &&
      alltrue([for label in split(".", var.cloudflare_domain.zone_name) : length(label) <= 63 && can(regex("^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$", label))]) &&
      length(var.cloudflare_domain.hostname) <= 253 &&
      length(split(".", var.cloudflare_domain.hostname)) >= 2 &&
      alltrue([for label in split(".", var.cloudflare_domain.hostname) : length(label) <= 63 && can(regex("^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$", label))]) &&
      lower(var.cloudflare_domain.hostname) != lower(var.cloudflare_domain.zone_name) &&
      endswith(lower(var.cloudflare_domain.hostname), ".${lower(var.cloudflare_domain.zone_name)}")
    )
    error_message = "cloudflare_domain must contain a 32-character zone ID, a valid zone name, and a valid non-apex hostname within that zone."
  }
}

variable "github_oidc_issuer_url" {
  description = "Issuer URL for the configured OIDC provider."
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "web_acl_arn" {
  description = "Optional customer-managed WAFv2 web ACL ARN for viewer access policy."
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "tags" {
  description = "Tags applied to supported AWS resources."
  type        = map(string)
  default     = {}
}

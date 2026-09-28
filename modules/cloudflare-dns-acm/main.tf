locals {
  hostname = lower(var.cloudflare_domain.hostname)
}

resource "aws_acm_certificate" "viewer" {
  provider          = aws.us_east_1
  domain_name       = local.hostname
  validation_method = "DNS"
  tags              = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_dns_record" "acm_validation" {
  for_each = {
    for option in aws_acm_certificate.viewer.domain_validation_options :
    option.domain_name => option
  }

  zone_id = var.cloudflare_domain.zone_id
  name    = trimsuffix(each.value.resource_record_name, ".")
  type    = each.value.resource_record_type
  content = trimsuffix(each.value.resource_record_value, ".")
  ttl     = 1
  proxied = false
}

resource "aws_acm_certificate_validation" "viewer" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.viewer.arn
  validation_record_fqdns = [for record in cloudflare_dns_record.acm_validation : record.name]
}

module "artifact_pages" {
  source = "../.."

  providers = {
    aws = aws
  }

  name_prefix               = var.name_prefix
  aws_region                = var.aws_region
  bucket_name               = var.bucket_name
  preview_retention_days    = var.preview_retention_days
  github_oidc_provider_arn  = var.github_oidc_provider_arn
  github_oidc_issuer_url    = var.github_oidc_issuer_url
  admin_github_subjects     = var.admin_github_subjects
  satellite_github_subjects = var.satellite_github_subjects
  aliases                   = [local.hostname]
  acm_certificate_arn       = aws_acm_certificate_validation.viewer.certificate_arn
  web_acl_arn               = var.web_acl_arn
  price_class               = var.price_class
  tags                      = var.tags
}

resource "cloudflare_dns_record" "distribution" {
  zone_id = var.cloudflare_domain.zone_id
  name    = local.hostname
  type    = "CNAME"
  content = module.artifact_pages.distribution_domain_name
  ttl     = 1
  proxied = false
}

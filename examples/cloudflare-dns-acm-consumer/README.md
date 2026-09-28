# Optional Cloudflare DNS + ACM consumer example

This clean caller demonstrates the optional composition for a non-apex AWS hostname. Its account ID, Cloudflare zone ID, OIDC subject, bucket name, and other values are placeholders. The validation script makes a temporary copy with AWS account checks skipped and uses an offline Cloudflare token; it never applies the example. Do not apply this configuration as written.

The caller configures its AWS provider in `aws_region`, an `aws.us_east_1` alias for CloudFront's ACM viewer certificate, and Cloudflare credentials through `CLOUDFLARE_API_TOKEN`. The example uses the minimum accepted whole-day setting, `preview_retention_days = 1`. S3 lifecycle expiration is asynchronous, so this is not an exact one-day or hours-scale deletion guarantee.

Review the [composition module guide](../../modules/cloudflare-dns-acm/README.md) before configuring real values. The root AWS module can still be used on its own with the default CloudFront hostname, or with caller-managed DNS and a caller-managed `us-east-1` ACM certificate.

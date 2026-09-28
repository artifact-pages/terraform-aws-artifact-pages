# Optional AWS + Cloudflare DNS and ACM composition

This child module composes the AWS deployment module with DNS-only Cloudflare records for one custom hostname. It is intended for the AWS verification branch (`aws.artifact-pages.dev`). The root AWS module only requires the AWS provider and continues to support the default CloudFront hostname or a caller-managed certificate and DNS configuration.

The caller must configure the default AWS provider in `aws_region`, an `aws.us_east_1` alias, and the Cloudflare provider. The alias creates and validates the ACM viewer certificate in `us-east-1`, as [CloudFront requires](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html). The module creates DNS validation records first and passes the validated certificate ARN and the same hostname to the AWS module's `aliases` and `acm_certificate_arn` inputs. This dependency makes certificate validation complete before the CloudFront distribution can use the alias.

The Cloudflare zone must already exist. `cloudflare_domain.hostname` must be a valid subdomain beneath `cloudflare_domain.zone_name`; the apex is rejected. The module creates only:

- DNS-only ACM validation CNAMEs in the supplied Cloudflare zone (`proxied = false`, automatic TTL).
- One DNS-only CNAME from the supplied hostname to the CloudFront distribution (`proxied = false`, automatic TTL).

It does not create Route 53 resources, change unrelated DNS names, manage the zone or nameservers, or proxy CloudFront traffic through Cloudflare. The apex product delivery path is independent and is not configured by this module.

## Inputs and outputs

The deployment inputs mirror the [root AWS module](../../README.md#inputs), with `cloudflare_domain` added:

| Name | Required | Description |
| --- | --- | --- |
| `cloudflare_domain.zone_id` | Yes | ID of the existing Cloudflare zone. |
| `cloudflare_domain.zone_name` | Yes | DNS name of that zone, used to validate the hostname boundary. |
| `cloudflare_domain.hostname` | Yes | One non-apex hostname within the zone. |

The module returns the root AWS deployment outputs plus `hostname`, `certificate_arn`, and `cloudflare_dns_records`. Credentials and provider configuration stay in the caller. The Cloudflare token needs DNS read and write access for the supplied zone; the AWS identity needs the permissions required by the root module and ACM in `us-east-1`.

## Existing records and replacement

This module takes Terraform ownership of its Cloudflare DNS records. If a matching record is already managed by another Terraform state, coordinate ownership before applying. For an existing record that should move into this state, import it instead of creating a duplicate. With Cloudflare provider 5.x, the import ID is `<zone_id>/<dns_record_id>`. Assuming the caller's module block is named `artifact_pages` and its hostname is `aws.artifact-pages.dev`:

```sh
terraform import 'module.artifact_pages.cloudflare_dns_record.distribution' '<zone_id>/<dns_record_id>'
terraform import 'module.artifact_pages.cloudflare_dns_record.acm_validation["aws.artifact-pages.dev"]' '<zone_id>/<dns_record_id>'
```

The ACM validation address uses the certificate validation option's domain name as its `for_each` key. Replace the example key with the configured hostname, and confirm the actual key and record IDs in the plan and Cloudflare dashboard before importing. The [Cloudflare provider import reference](https://github.com/cloudflare/terraform-provider-cloudflare/blob/main/docs/resources/dns_record.md#import) documents the provider ID format.

The ACM certificate uses `create_before_destroy`; a hostname change requests and validates the replacement certificate while the current certificate remains available. The matching CloudFront alias and CNAME then update through Terraform. Review the plan for both certificates, the distribution update, and DNS changes before applying. Certificate and CloudFront propagation take time, and reverting the Terraform source does not reverse DNS or certificate changes already applied.

## Real-plan review checklist

Before an approved plan for the selected `aws.artifact-pages.dev` target, verify the caller's AWS default provider points to the intended account and `aws_region`, while `aws.us_east_1` points to the same account in `us-east-1`. Confirm the Cloudflare token and `cloudflare_domain.zone_id` refer to the existing `artifact-pages.dev` zone. Review the full plan and check that:

- The requested ACM certificate's domain is exactly `aws.artifact-pages.dev`, and the certificate validation waiter completes before the CloudFront distribution uses it.
- The ACM validation records are CNAMEs in the selected Cloudflare zone with `proxied = false` and automatic TTL.
- There is one distribution CNAME for `aws.artifact-pages.dev`, it points to the planned CloudFront distribution hostname, and it has `proxied = false` and automatic TTL.
- The CloudFront alias is exactly `aws.artifact-pages.dev` and its viewer certificate ARN is the validated `us-east-1` certificate.
- The plan contains no Route 53 resources, apex record, unrelated Cloudflare records, or unreviewed AWS replacements and deletions.

After a separately approved apply, wait for ACM `ISSUED` and CloudFront `Deployed`, then verify the DNS-only CNAME resolves to the distribution hostname, TLS succeeds for `aws.artifact-pages.dev`, and the browser can load the deployed site. These checks are live T15 proof; the local validation script does not perform them.

## Validation boundary

The local example and validation script use placeholder values, skip AWS account checks in a temporary copy, and do not contact AWS or Cloudflare. They verify source wiring and produce an offline create-only plan; they do not prove DNS validation, certificate issuance, CloudFront deployment, or browser delivery. Those require a separately approved plan and a live disposable target.

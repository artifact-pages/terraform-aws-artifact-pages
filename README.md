# AWS reference deployment

This module provisions a private S3 origin and CloudFront distribution for the provider-neutral Artifact Pages projection. CloudFront reads the bucket through Origin Access Control; the bucket blocks public access. The viewer-request function keeps `/_control` private, passes storage and asset paths to S3, and rewrites logical browser routes to `/index.html`. A viewer-response function adds a path-scoped trusted-HTML Content Security Policy to raw production artifact and preview paths. It permits HTTPS, blocks insecure HTTP, and grants no CORS access. Preview HTML stays on the application origin in an ordinary unsandboxed iframe: the iframe contains layout and CSS, while its scripts retain same-origin access to the parent DOM and storage.

The module also creates one admin GitHub OIDC role and one optional satellite role per site ID. The admin role can apply the registry, publish the application plane (`index.html`, `preview-bridge.js`, `LICENSE`, `THIRD_PARTY_NOTICES.txt`, and `assets/*`), clean removed site prefixes, update registry control records, and request CloudFront invalidations. Each satellite role reads the deployed registry and its site's current indexes, artifacts, and preview records, and can write only its site's artifacts, indexes, previews, and retained site lock. GitHub OIDC subjects are exact inputs so a caller can restrict each role to selected branches or environments.

## Inputs

Create the GitHub OIDC provider in the AWS account first. The AWS provider configuration belongs to the caller, which can also pass assume-role, endpoint, and account-level settings. Set its region to the same value as `aws_region`.

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `bucket_name` | Yes | — | Globally unique name for the private S3 origin bucket. |
| `aws_region` | Yes | — | AWS region configured on the caller's `aws` provider and written to the deployment output. |
| `preview_retention_days` | Yes | — | Whole-number lifetime from 1 through 36500 for current and noncurrent `_previews/` objects. |
| `github_oidc_provider_arn` | Yes | — | ARN of the existing GitHub Actions OIDC provider in the AWS account. |
| `admin_github_subjects` | Yes | — | Exact GitHub OIDC `sub` claims allowed to assume the administrative role. |
| `satellite_github_subjects` | No | `{}` | Map of registered site IDs to exact `sub` claims for per-site publisher roles. |
| `name_prefix` | No | `artifact-pages` | Lowercase prefix for named AWS resources. |
| `github_oidc_issuer_url` | No | `https://token.actions.githubusercontent.com` | Issuer URL for the existing OIDC provider. |
| `aliases` | No | `[]` | Optional CloudFront alternate domain names. DNS is managed by the caller. |
| `acm_certificate_arn` | No | `null` | ACM certificate ARN in `us-east-1`, required when aliases are set. |
| `web_acl_arn` | No | `null` | Optional customer-managed WAFv2 web ACL ARN. |
| `price_class` | No | `PriceClass_100` | CloudFront edge location class. |
| `tags` | No | `{}` | Tags applied to supported resources. |

## Outputs

| Name | Description |
| --- | --- |
| `bucket_name` | Private S3 origin bucket name. |
| `distribution_id` | CloudFront distribution ID for the deployment configuration. |
| `distribution_domain_name` | CloudFront distribution hostname for DNS and browser checks. |
| `admin_role_arn` | GitHub OIDC role for registry, application-plane, and administrative site operations. |
| `satellite_role_arns` | Per-site publisher role ARNs keyed by site ID. |
| `aws_deployment_config_yaml` | Non-secret AWS target configuration for the CLI. |

The module does not create DNS records or a WAF policy. A satellite role only exists for a key in `satellite_github_subjects`; registry edits do not change these permissions. Update the module inputs separately when repository identity or the intended site boundary changes.

## Optional Cloudflare DNS and ACM composition

The root AWS module remains AWS-only and keeps its generic custom-domain path: configure `aliases` and `acm_certificate_arn`, then manage DNS and the `us-east-1` certificate in your own Terraform configuration. Callers that use the default CloudFront hostname need no Cloudflare provider or certificate.

For callers that want Cloudflare-managed DNS for a custom AWS hostname, [`modules/cloudflare-dns-acm`](modules/cloudflare-dns-acm) composes this module with a caller-supplied Cloudflare zone and hostname plus an ACM certificate in `us-east-1`. It owns only the supplied non-apex hostname, its ACM DNS-validation CNAMEs, and a DNS-only CNAME to the resulting CloudFront distribution. It does not create a Route 53 zone or records, proxy traffic through Cloudflare, or manage the zone apex. The [consumer example](examples/cloudflare-dns-acm-consumer) shows the required default and `us-east-1` AWS providers and the Cloudflare provider.

The composition is a separate source path with an additional Cloudflare provider requirement. Existing AWS-only callers do not inherit it. See its README for record import, certificate replacement, provider permissions, and plan review guidance.

Satellite IAM role names include the full site ID when they fit AWS's 64-character limit. Longer IDs use a stable hash suffix; `satellite_role_arns` remains keyed by the full site ID either way.

The CloudFront cache policies bound shared-cache freshness at 60 seconds for `/_indexes/*`, 300 seconds for `/_artifacts/*`, zero for the shell and `/_previews/*`, and honor per-object `Cache-Control` under `/assets/*` with a one-year maximum. Fixed-name assets revalidate; content-hashed assets can use the one-year immutable policy. A private S3 403 or 404 for a missing projection object maps to a 404 response. `/_errors/not-found.html` is a small managed text page used for that response.

The viewer-response function is attached only to `/_artifacts/*` and `/_previews/*`. It builds the same-origin resource path from the requested artifact site or preview revision, then adds HTTPS as a source for external resources. Inline scripts/styles and `eval` are permitted for published HTML; HTTP resources remain blocked. The function does not add `Access-Control-Allow-Origin`, `null` or wildcard CORS, and it does not isolate trusted preview JavaScript from the same-origin application. CloudFront Function viewer-response invocations are included in the account cost review alongside the existing viewer-request route function.

`preview_retention_days` expires current objects and noncurrent versions under `_previews/` through S3 lifecycle management, then removes expired delete markers. S3 versioning is bucket-wide rather than prefix-scoped; this module manages it as `Suspended` to avoid generating new unique versions for preview rewrites. The lifecycle rules also remove existing noncurrent preview versions if the bucket had been versioned before suspension. They do not alter noncurrent versions outside `_previews/`. Incomplete multipart uploads under the prefix are aborted after seven days.

S3 lifecycle processing is asynchronous. An expired object can remain readable for a period while S3 processes its lifecycle action, and a CDN or downstream cache can add further delay. CloudFront uses a zero-TTL policy for `/_previews/*`, but this does not make lifecycle expiration an exact-time revocation guarantee. Verify origin and viewer behavior in T4/T8/T15 after applying to a disposable provider target.

## Apply and configure the CLI

Use a reviewed `terraform plan` before applying. CloudFront distribution changes can take time to propagate. After apply, place the `aws_deployment_config_yaml` output in a local config or a pinned remote config file. Give the admin and satellite workflows their respective role ARNs; each workflow exchanges its GitHub OIDC token for temporary AWS credentials.

The module follows AWS's recommended signed OAC access for private S3 origins and uses a CloudFront Function viewer-response association for dynamic path-scoped CSP. See [Restrict access to an Amazon S3 origin](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html), [CloudFront Functions event structure](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/functions-event-structure.html), [CloudFront distribution Terraform resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution.html), and [CloudFront cache behavior TTL guidance](https://docs.aws.amazon.com/AmazonCloudFront/latest/APIReference/API_DefaultCacheBehavior.html).

CloudFront routing, missing-object responses, IAM policy scope, effective browser headers, OIDC assumptions, and a live publish/unregister smoke still require deployment verification in T4, T14, and T15. This source module is not evidence that an AWS account has been configured correctly.

## Registry package and migration

This repository is the source of truth for the independently released AWS module. The OSS reference implementation will be retired after consumer documentation and source references are migrated here; the Terraform resources are not maintained as a second implementation.

The intended Registry address is `tasuku43/artifact-pages/aws`. Candidate version `0.1.0` is a preparation label only: the owner has not selected the public version, pushed repository contents or tags, connected GitHub to Terraform Registry, or published a module. AWS deployment and IAM enforcement remain unverified in T15.

Before release, verify that this GitHub repository is public, its description is suitable for the Registry module listing, the namespace is eligible, and at least one owner-approved semantic-version tag will be available. After the owner authorizes publication, push the reviewed source commit and immutable `vX.Y.Z` tag, connect the repository to Terraform Registry, publish the module, and retrieve that exact version in a clean external consumer. Do not overwrite or move any published tag.

The former OSS `infra/aws` directory was a root Terraform configuration, not a child-module source, and the OSS repo has no checked-in caller module block for it. Existing root-config state therefore uses addresses such as `aws_s3_bucket.origin`; wrapping the package in `module "artifact_pages"` changes those to `module.artifact_pages.aws_s3_bucket.origin`. This is a state-address migration, not a source-only change. Back up state and list and review every AWS resource and data address owned by that root configuration. Perform the migration in the same backend and workspace that contain the old state. If the configuration moves to a different directory, initialize it against that same backend/workspace; for local state, explicitly transfer the saved state into the new working directory before moving addresses. Never run `state mv` against a fresh empty local state. After confirming the target state, update the configuration to call this module and run `terraform init`; Terraform must be initialized before the address moves. Then move each address under the module path before planning. For example:

```sh
terraform state mv 'aws_s3_bucket.origin' 'module.artifact_pages.aws_s3_bucket.origin'
```

Repeat for each resource and data source from the former root configuration using its exact current and new address. Do not move unrelated resources in a shared state. A no-move source-only migration applies only to a caller that already wrapped the old implementation in a Terraform module; no such caller is present in this OSS repository. After the moves, inspect a fresh plan for address changes, replacements, and IAM differences, and keep the backup until the migration is accepted. Changing a module source or reverting the source ref does not roll back infrastructure state.

The local caller and validation script are not deployment authorization. The script checks formatting, backend-free initialization, validation, the role/cache/lifecycle source contract, and a no-refresh plan from a temporary copy with provider account checks skipped. It does not use real AWS credentials, assume GitHub OIDC roles, or contact an AWS account.

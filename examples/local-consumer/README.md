# Local AWS module contract plan

This clean caller uses a local path so maintainers can validate the package before Registry publication. Its account ID, OIDC subjects, bucket name, and other values are placeholders; never apply its plan. The validation script creates a temporary copy with AWS provider account checks skipped to prevent an account request. For consumers, use the Registry source in [`examples/registry-consumer`](../registry-consumer) after publication.

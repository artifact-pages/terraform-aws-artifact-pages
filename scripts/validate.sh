#!/usr/bin/env bash
set -euo pipefail

terraform_bin="${TERRAFORM_BIN:-terraform}"
terraform_version="$($terraform_bin version -json | node -e 'let input="";process.stdin.on("data",chunk=>input+=chunk).on("end",()=>process.stdout.write(JSON.parse(input).terraform_version))')"
if [[ "$terraform_version" != "1.9.8" ]]; then
  printf 'Expected Terraform 1.9.8, got %s\n' "$terraform_version" >&2
  exit 1
fi

export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/tmp/terraform-provider-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

"$terraform_bin" fmt -check -recursive
"$terraform_bin" init -backend=false -input=false -lockfile=readonly
"$terraform_bin" validate
"$terraform_bin" -chdir=examples/local-consumer init -backend=false -input=false -lockfile=readonly
"$terraform_bin" -chdir=examples/local-consumer validate
node --test tests/*.test.js

temporary_root="$(mktemp -d /tmp/artifact-pages-aws-validation.XXXXXX)"
trap 'rm -rf "$temporary_root"' EXIT
mkdir -p "$temporary_root/module/examples/local-consumer"
cp main.tf variables.tf outputs.tf routes.js trusted-html-policy.js versions.tf .terraform.lock.hcl "$temporary_root/module/"
cp examples/local-consumer/main.tf \
  examples/local-consumer/variables.tf \
  examples/local-consumer/outputs.tf \
  examples/local-consumer/versions.tf \
  examples/local-consumer/terraform.tfvars.example \
  examples/local-consumer/.terraform.lock.hcl \
  "$temporary_root/module/examples/local-consumer/"
perl -0pi -e 's/provider "aws" \{\n  region = var\.aws_region\n\}/provider "aws" {\n  region                      = var.aws_region\n  skip_credentials_validation = true\n  skip_metadata_api_check     = true\n  skip_region_validation      = true\n  skip_requesting_account_id  = true\n}/' "$temporary_root/module/examples/local-consumer/versions.tf"
if ! rg -q 'skip_credentials_validation\s*=\s*true' "$temporary_root/module/examples/local-consumer/versions.tf"; then
  printf 'Failed to prepare offline-only provider checks in the temporary validation copy.\n' >&2
  exit 1
fi

"$terraform_bin" -chdir="$temporary_root/module" init -backend=false -input=false -lockfile=readonly
"$terraform_bin" -chdir="$temporary_root/module/examples/local-consumer" init -backend=false -input=false
AWS_ACCESS_KEY_ID=offline-validation AWS_SECRET_ACCESS_KEY=offline-validation AWS_EC2_METADATA_DISABLED=true \
  "$terraform_bin" -chdir="$temporary_root/module/examples/local-consumer" plan -refresh=false -input=false -lock=false -var-file=terraform.tfvars.example -out="$temporary_root/aws.plan"
"$terraform_bin" -chdir="$temporary_root/module/examples/local-consumer" show -json "$temporary_root/aws.plan" |
  node -e 'let input="";process.stdin.on("data",chunk=>input+=chunk).on("end",()=>{const plan=JSON.parse(input);const changes=plan.resource_changes||[];const counts=changes.reduce((result,item)=>{for(const action of item.change.actions)result[action]=(result[action]||0)+1;return result},{}) ;if(changes.length===0||changes.some(item=>item.change.actions.some(action=>action!=="create"))){process.stderr.write(JSON.stringify({resourceCount:changes.length,counts},null,2)+"\n");process.exit(1)}process.stdout.write(JSON.stringify({resourceCount:changes.length,counts},null,2)+"\n")})'

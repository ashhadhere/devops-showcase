#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
terraform fmt -check -recursive
for dir in bootstrap environments/portfolio addons modules/network modules/eks; do
  terraform -chdir="$dir" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$dir" validate
done
terraform -chdir=modules/network test
terraform -chdir=modules/eks test
tflint --init
tflint --recursive --config="$(pwd)/.tflint.hcl"
checkov -d . --config-file .checkov.yml

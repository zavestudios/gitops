#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

kustomize_bin="${KUSTOMIZE_BIN:-kustomize}"

if ! command -v "$kustomize_bin" >/dev/null 2>&1; then
  echo "error: kustomize is required" >&2
  exit 1
fi

rendered_namespaces() {
  "$kustomize_bin" build --load-restrictor LoadRestrictionsNone "$1" |
    awk '
      /^metadata:$/ { in_metadata = 1; next }
      in_metadata && /^  namespace:/ { print $2 }
      in_metadata && /^[^[:space:]]/ { in_metadata = 0 }
    ' |
    sort -u |
    paste -sd, -
}

dependencies() {
  awk '
    /^  dependsOn:$/ { in_dependencies = 1; next }
    in_dependencies && /^    - name:/ { print $3; next }
    in_dependencies && /^  [[:alnum:]]/ { in_dependencies = 0 }
  ' "$1"
}

assert_namespaces() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(rendered_namespaces "$path")"

  if [[ "$actual" != "$expected" ]]; then
    echo "error: $path renders into unexpected namespaces" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    return 1
  fi
}

assert_dependency() {
  local manifest="$1"
  local expected="$2"

  if ! dependencies "$manifest" | grep -Fxq "$expected"; then
    echo "error: $manifest must depend on $expected" >&2
    return 1
  fi
}

# Namespace sets are the review contract for resources rendered directly by
# each top-level reconciliation path. Update this list and the ownership matrix
# together when a path intentionally changes its namespace surface.
assert_namespaces platform/core \
  "default,ingress,kube-node-lease,kube-public,kube-system,platform"
assert_namespaces platform/keycloak "keycloak"
assert_namespaces bigbang/source "bigbang"
assert_namespaces bigbang/foundation "bigbang"
assert_namespaces bigbang/policy "bigbang"
assert_namespaces bigbang/observability "bigbang"
assert_namespaces platform/runtime "alloy,argocd,kyverno,platform,vault"
assert_namespaces platform/services "platform"

# Cross-unit writes require a direct dependency on the namespace authority.
assert_dependency clusters/on-prem/keycloak-secrets-kustomization.yaml \
  on-prem-platform-core
assert_dependency clusters/on-prem/bigbang-foundation-kustomization.yaml \
  on-prem-bigbang-source
assert_dependency clusters/on-prem/bigbang-policy-kustomization.yaml \
  on-prem-bigbang-source
assert_dependency clusters/on-prem/bigbang-observability-kustomization.yaml \
  on-prem-bigbang-source
assert_dependency clusters/on-prem/platform-runtime-kustomization.yaml \
  on-prem-platform-core
assert_dependency clusters/on-prem/platform-runtime-kustomization.yaml \
  on-prem-bigbang-foundation
assert_dependency clusters/on-prem/platform-runtime-kustomization.yaml \
  on-prem-bigbang-policy
assert_dependency clusters/on-prem/platform-runtime-kustomization.yaml \
  on-prem-bigbang-observability
assert_dependency clusters/on-prem/platform-services-kustomization.yaml \
  on-prem-platform-core
assert_dependency clusters/on-prem/platform-services-kustomization.yaml \
  on-prem-platform-runtime

echo "Namespace ownership audit passed."

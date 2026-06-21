#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 <bigbang-source-dir> <output-dir>" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$(cd "$1" && pwd)"
output_dir="$2"
expected_version="3.17.0"
expected_commit="eab9bb69d206a59a10e0c9182800870f32d11dbc"

if ! command -v helm >/dev/null 2>&1; then
  echo "error: helm is required" >&2
  exit 1
fi

actual_version="$(awk '$1 == "version:" { print $2; exit }' "$source_dir/chart/Chart.yaml")"
actual_commit="$(git -C "$source_dir" rev-parse HEAD)"
helm_version="$(helm version --short)"

if [[ "$actual_version" != "$expected_version" ]]; then
  echo "error: expected Big Bang $expected_version, found $actual_version" >&2
  exit 1
fi

if [[ "$actual_commit" != "$expected_commit" ]]; then
  echo "error: expected Big Bang commit $expected_commit, found $actual_commit" >&2
  exit 1
fi

if [[ -d "$output_dir" ]] && [[ -n "$(find "$output_dir" -mindepth 1 -print -quit)" ]]; then
  echo "error: output directory must be empty: $output_dir" >&2
  exit 1
fi

mkdir -p "$output_dir"
render_dir="$(mktemp -d)"
trap 'rm -rf "$render_dir"' EXIT

for family in foundation policy observability; do
  family_render="$render_dir/$family"
  family_output="$output_dir/$family"

  helm template "bigbang-$family" "$source_dir/chart" \
    --namespace bigbang \
    --values "$repo_root/bigbang/$family/values-$family.yaml" \
    --output-dir "$family_render" \
    --skip-tests >/dev/null

  mkdir -p "$family_output"
  while IFS= read -r values_file; do
    package="$(basename "$(dirname "$values_file")")"
    {
      printf '# Offline-rendered Big Bang effective values; not a Kubernetes resource.\n'
      awk '
        /^stringData:$/ { in_values = 1; next }
        in_values { sub(/^  /, ""); sub(/[[:space:]]+$/, ""); print }
      ' "$values_file"
    } > "$family_output/$package.values.txt"
  done < <(find "$family_render/bigbang/templates" -path '*/values.yaml' -type f | sort)
done

printf '%s\n' \
  "Big Bang version: $actual_version" \
  "Big Bang commit: $actual_commit" \
  "Helm version: $helm_version" \
  "Generated from repository family values." > "$output_dir/SOURCE"

(
  cd "$output_dir"
  find . -type f -name '*.values.txt' -exec shasum -a 256 {} \; | sort > SHA256SUMS
)

echo "Rendered effective values to $output_dir"

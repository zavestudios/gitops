#!/bin/bash
# helm-trace-value.sh - Trace where a value is used in rendered templates
#
# Usage: ./helm-trace-value.sh <chart-path> <values-file> <search-key>
# Example: ./helm-trace-value.sh ~/bigbang values/sandbox.yaml "istio.enabled"

set -e

CHART_PATH=$1
VALUES_FILE=$2
SEARCH_KEY=$3

if [ -z "$CHART_PATH" ] || [ -z "$VALUES_FILE" ] || [ -z "$SEARCH_KEY" ]; then
    echo "Usage: $0 <chart-path> <values-file> <search-key>"
    echo ""
    echo "Examples:"
    echo "  $0 ~/bigbang values/sandbox.yaml istio.enabled"
    echo "  $0 ~/bigbang values/sandbox.yaml 'image.repository'"
    exit 1
fi

echo "========================================="
echo "Tracing value: $SEARCH_KEY"
echo "Chart: $CHART_PATH"
echo "Values: $VALUES_FILE"
echo "========================================="
echo ""

# Render templates and search
echo "Rendered occurrences:"
helm template temp "$CHART_PATH" -f "$VALUES_FILE" 2>/dev/null | grep -n "$SEARCH_KEY" || echo "Not found in rendered output"

echo ""
echo "========================================="
echo "Checking source templates:"
echo "========================================="

# Find template files that reference this value
find "$CHART_PATH" -name "*.yaml" -o -name "*.tpl" | while read -r file; do
    if grep -l "$SEARCH_KEY" "$file" > /dev/null 2>&1; then
        echo ""
        echo "Found in: $file"
        grep -n "$SEARCH_KEY" "$file" | head -5
    fi
done

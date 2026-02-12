#!/bin/bash
# helm-show-values.sh - Show all values that would be used in a chart
#
# Usage: ./helm-show-values.sh <chart-path> <values-file> [filter]
# Example: ./helm-show-values.sh ~/bigbang values/sandbox.yaml istio

set -e

CHART_PATH=$1
VALUES_FILE=$2
FILTER=$3

if [ -z "$CHART_PATH" ]; then
    echo "Usage: $0 <chart-path> [values-file] [filter]"
    echo ""
    echo "Examples:"
    echo "  $0 ~/bigbang                                  # Show default values"
    echo "  $0 ~/bigbang values/sandbox.yaml             # Show merged values"
    echo "  $0 ~/bigbang values/sandbox.yaml istio       # Filter for 'istio'"
    exit 1
fi

echo "========================================="
echo "Chart Values"
echo "Chart: $CHART_PATH"
if [ -n "$VALUES_FILE" ]; then
    echo "Values file: $VALUES_FILE"
fi
if [ -n "$FILTER" ]; then
    echo "Filter: $FILTER"
fi
echo "========================================="
echo ""

if [ -n "$VALUES_FILE" ]; then
    if [ -n "$FILTER" ]; then
        helm template temp "$CHART_PATH" -f "$VALUES_FILE" --show-only values.yaml 2>/dev/null | yq eval ". | select(. | keys | contains([\"$FILTER\"]))"
    else
        helm template temp "$CHART_PATH" -f "$VALUES_FILE" --show-only values.yaml 2>/dev/null | head -100
        echo ""
        echo "(Showing first 100 lines - pipe through 'less' or add filter for more)"
    fi
else
    if [ -n "$FILTER" ]; then
        helm show values "$CHART_PATH" | yq eval ".$FILTER"
    else
        helm show values "$CHART_PATH" | head -100
        echo ""
        echo "(Showing first 100 lines - pipe through 'less' or add filter for more)"
    fi
fi

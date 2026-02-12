#!/bin/bash
# helm-render-template.sh - Render a specific template to see the actual output
#
# Usage: ./helm-render-template.sh <chart-path> <values-file> <template-file>
# Example: ./helm-render-template.sh ~/bigbang values/sandbox.yaml templates/istio/deployment.yaml

set -e

CHART_PATH=$1
VALUES_FILE=$2
TEMPLATE_FILE=$3

if [ -z "$CHART_PATH" ] || [ -z "$VALUES_FILE" ]; then
    echo "Usage: $0 <chart-path> <values-file> [template-file]"
    echo ""
    echo "Examples:"
    echo "  $0 ~/bigbang values/sandbox.yaml                           # Render all templates"
    echo "  $0 ~/bigbang values/sandbox.yaml templates/istio/          # Render istio templates"
    echo "  $0 ~/bigbang values/sandbox.yaml --debug                   # Debug mode"
    exit 1
fi

echo "========================================="
echo "Rendering Templates"
echo "Chart: $CHART_PATH"
echo "Values: $VALUES_FILE"
if [ -n "$TEMPLATE_FILE" ]; then
    echo "Template: $TEMPLATE_FILE"
fi
echo "========================================="
echo ""

if [ "$TEMPLATE_FILE" == "--debug" ]; then
    helm template temp "$CHART_PATH" -f "$VALUES_FILE" --debug 2>&1 | less
elif [ -n "$TEMPLATE_FILE" ]; then
    helm template temp "$CHART_PATH" -f "$VALUES_FILE" -s "$TEMPLATE_FILE"
else
    # Check if output is being piped
    if [ -t 1 ]; then
        # Interactive terminal - use less
        helm template temp "$CHART_PATH" -f "$VALUES_FILE" | less
    else
        # Being piped - output directly
        helm template temp "$CHART_PATH" -f "$VALUES_FILE"
    fi
fi

# Helm Debugging Toolkit

Tools for understanding Helm template resolution and tracing values through complex charts like Big Bang.

## Prerequisites

```bash
# On bastion, ensure you have:
helm version    # Helm 3.x
yq --version    # yq for YAML processing
```

## Scripts

### 1. helm-trace-value.sh
**Purpose:** Find where a specific value is used in templates and rendered output

**Usage:**
```bash
./helm-trace-value.sh <chart-path> <values-file> <search-key>
```

**Examples:**
```bash
# Trace where istio.enabled is used
./helm-trace-value.sh ~/bigbang ../bigbang/values/sandbox.yaml "istio.enabled"

# Find all image repository references
./helm-trace-value.sh ~/bigbang ../bigbang/values/sandbox.yaml "image.repository"

# Trace a specific ArgoCD value
./helm-trace-value.sh ~/bigbang ../bigbang/values/sandbox.yaml "argocd.server.replicas"
```

### 2. helm-show-values.sh
**Purpose:** Show the complete merged values that will be used

**Usage:**
```bash
./helm-show-values.sh <chart-path> [values-file] [filter]
```

**Examples:**
```bash
# Show all default values from the chart
./helm-show-values.sh ~/bigbang

# Show merged values (defaults + your overrides)
./helm-show-values.sh ~/bigbang ../bigbang/values/sandbox.yaml

# Filter to just istio values
./helm-show-values.sh ~/bigbang ../bigbang/values/sandbox.yaml istio
```

### 3. helm-render-template.sh
**Purpose:** Render templates to see the actual Kubernetes manifests that will be created

**Usage:**
```bash
./helm-render-template.sh <chart-path> <values-file> [template-file|--debug]
```

**Examples:**
```bash
# Render all templates
./helm-render-template.sh ~/bigbang ../bigbang/values/sandbox.yaml

# Render with debug output
./helm-render-template.sh ~/bigbang ../bigbang/values/sandbox.yaml --debug

# Render specific template
./helm-render-template.sh ~/bigbang ../bigbang/values/sandbox.yaml templates/istio/
```

## Workflow for Understanding Template Resolution

### Step 1: Start with a value you want to trace
```bash
# Example: Understanding how istio.enabled works
echo "istio:
  enabled: true" > test-values.yaml
```

### Step 2: See the default values
```bash
./helm-show-values.sh ~/bigbang "" istio
```

### Step 3: See your merged values
```bash
./helm-show-values.sh ~/bigbang test-values.yaml istio
```

### Step 4: Find where it's used in templates
```bash
./helm-trace-value.sh ~/bigbang test-values.yaml "istio.enabled"
```

### Step 5: Render the actual output
```bash
./helm-render-template.sh ~/bigbang test-values.yaml | grep -A 10 -B 10 "istio"
```

## Common Patterns in Big Bang

### Conditional Rendering
```yaml
{{- if .Values.istio.enabled }}
# This block only renders if istio.enabled is true
{{- end }}
```

### Value References
```yaml
# Direct reference
{{ .Values.istio.version }}

# With default fallback
{{ .Values.istio.version | default "1.20.0" }}

# Nested reference
{{ .Values.istio.ingressGateways.public.type }}
```

### Template Includes
```yaml
# Include another template
{{ include "bigbang.labels" . }}

# Include with custom context
{{ include "istio.image" .Values.istio }}
```

## Tips

1. **Start small:** Trace one value at a time
2. **Work backwards:** Start from rendered output → find in template → find in values
3. **Use grep liberally:** `helm template ... | grep -C 5 "search-term"`
4. **Check dependencies:** Big Bang has sub-charts with their own values
5. **Debug mode is your friend:** `--debug` shows exactly what Helm is doing

## Real-World Example: Tracing Istio Image

```bash
# 1. What's the current istio image value?
./helm-show-values.sh ~/bigbang ../bigbang/values/sandbox.yaml istio | grep -i image

# 2. Where is it used in templates?
./helm-trace-value.sh ~/bigbang ../bigbang/values/sandbox.yaml "istio.*image"

# 3. What actually gets rendered?
./helm-render-template.sh ~/bigbang ../bigbang/values/sandbox.yaml | grep "image:" | head -20

# 4. Edit your values to override
vim ../bigbang/values/sandbox.yaml
# Add: istio.values.global.hub: docker.io/istio

# 5. Verify the change
./helm-render-template.sh ~/bigbang ../bigbang/values/sandbox.yaml | grep "docker.io/istio"
```

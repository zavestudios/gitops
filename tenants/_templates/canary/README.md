# Tenant Canary Template

Use these manifests to add an isolated canary path for any tenant workload.

## Template Variables

- `__WORKLOAD__` - canonical workload name (for example `mia`)
- `__NAMESPACE__` - namespace (often same as workload)
- `__DIGEST__` - candidate image digest (`sha256:...`)
- `__VERSION__` - version label value (for example `sha-6257797`)
- `__CANARY_HOST__` - host for canary ingress (for example `mia-canary-sandbox.zavestudios.com`)

## Notes

- Template defaults should start with `replicas: 0` for safe activation.
- Increase canary replicas to `1` only during validation.
- Keep stable and canary services separate to avoid traffic mixing.

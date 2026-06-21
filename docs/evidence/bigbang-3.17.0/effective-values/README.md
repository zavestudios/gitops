# Big Bang Effective Values Evidence

These files are offline-rendered configuration evidence from Big Bang `3.17.0`.
They are not live Kubernetes Secret exports and contain no values read from the
cluster.

Each `.values.txt` file preserves only the generated `common`, `defaults`, and
`overlays` layers consumed by a child `HelmRelease`. The Kubernetes `Secret`
wrapper is deliberately removed, and the non-YAML extension is intentional:
these are inert rendered snapshots, not deployable unencrypted Secret
manifests. A value in `defaults` may be replaced by `overlays`; for example, the
upstream Keycloak database placeholder is replaced by the
`keycloak-postgres-credentials` Secret reference.

Trailing whitespace is removed during generation. This changes no YAML values
and keeps the evidence compatible with repository whitespace checks.

Regenerate into an empty directory with:

```bash
scripts/render-bigbang-package-inventory.sh \
  /path/to/bigbang-3.17.0 \
  /tmp/bigbang-effective-values
```

Compare `SHA256SUMS` before accepting a snapshot change.

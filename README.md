# ZaveStudios GitOps

GitOps source of truth for the ZaveStudios platform.

This repository defines desired cluster state for platform services and tenant workloads. Flux reconciles manifests from this repository into Kubernetes.

## Scope

- Cluster-level platform resources (`platform/`)
- Environment overlays (`clusters/`)
- Platform service bundles (`bigbang/`)
- Tenant app composition (`tenants/`)
- Operational helper scripts (`tools/`)

## Repository Layout

```text
.
├── clusters/
│   └── sandbox/
│       └── kustomization.yaml
├── platform/
│   ├── kustomization.yaml
│   └── namespaces/
├── bigbang/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── gitrepository.yaml
│   ├── fluxkustomization.yaml
│   └── values/
├── tenants/
├── docs/
└── tools/
```

## Reconciliation Model

- `clusters/<env>/kustomization.yaml` is the environment entrypoint.
- Environment entrypoint composes platform resources first.
- Big Bang and tenant resources are enabled as explicit layers when ready.
- Each layer is declarative and versioned in Git.

Current `sandbox` entrypoint intentionally keeps Big Bang and tenant layers commented while baseline platform resources are stabilized.

## Big Bang Integration

`bigbang/` contains Flux resources for deploying Big Bang in a controlled, reproducible way:

- `GitRepository` pins an explicit Big Bang tag.
- `Kustomization` reconciles Big Bang `./base` path.
- `configMapGenerator` injects environment-specific values from `values/sandbox.yaml`.

The current sandbox values prioritize a minimal package set and public image sources.

## Bootstrap and Apply

Run these from a workstation with cluster access:

```bash
# Validate kustomization composition
kubectl kustomize clusters/sandbox

# Apply baseline platform resources
kubectl apply -k clusters/sandbox
```

When ready to enable additional layers, uncomment references in `clusters/sandbox/kustomization.yaml` and re-apply.

## Workflow

1. Create branch and commit manifest change.
2. Validate manifest rendering locally.
3. Open PR and review reconciliation impact.
4. Merge to main.
5. Flux reconciles to cluster.

## Documentation

- `docs/image-registry-mappings.md`: Public image mapping used for Big Bang sandbox deployments.
- `tools/helm-debug/README.md`: Helm debugging commands for value tracing and template rendering.

## Conventions

- Keep environment-specific values under deterministic paths.
- Pin upstream versions; avoid floating tags.
- Prefer small, auditable PRs for infrastructure changes.
- Treat this repository as the single source of truth for platform desired state.

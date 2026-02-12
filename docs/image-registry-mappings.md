# Public Image Registry Mappings for Big Bang

This document maps Iron Bank (registry1.dso.mil) images to their public registry equivalents.

**Purpose:** Enable Big Bang deployment without Iron Bank credentials by using publicly available images.

## Istio Components

**Official Registry:** Docker Hub (`docker.io/istio/*`)

| Component | Public Image | Notes |
|-----------|-------------|-------|
| Pilot (Istiod) | `docker.io/istio/pilot:1.20.0` | Control plane |
| Proxy | `docker.io/istio/proxyv2:1.20.0` | Sidecar proxy |
| Base | `docker.io/istio/base:1.20.0` | Base image |
| Ingress Gateway | `docker.io/istio/proxyv2:1.20.0` | Uses proxy image |

**Source:** [Istio Docker Hub](https://hub.docker.com/u/istio)

## ArgoCD

**Official Registry:** Quay.io (`quay.io/argoproj/*`)

| Component | Public Image | Notes |
|-----------|-------------|-------|
| Server | `quay.io/argoproj/argocd:v2.10.0` | API server + UI |
| Repo Server | `quay.io/argoproj/argocd:v2.10.0` | Repository server |
| Application Controller | `quay.io/argoproj/argocd:v2.10.0` | App controller |
| Dex | `quay.io/dexidp/dex:v2.37.0` | SSO/OAuth |
| Redis | `docker.io/redis:7.0` | Cache |

**Sources:**
- [ArgoCD Quay Repository](https://quay.io/repository/argoproj/argocd)
- [ArgoCD Image Updater Docs](https://argocd-image-updater.readthedocs.io/en/stable/configuration/registries/)

## Monitoring Stack (Prometheus Operator)

**Official Registries:** Docker Hub (`prom/*`, `grafana/*`) and registry.k8s.io

| Component | Public Image | Notes |
|-----------|-------------|-------|
| Prometheus | `docker.io/prom/prometheus:v2.50.0` | Metrics database |
| Alertmanager | `docker.io/prom/alertmanager:v0.27.0` | Alert handling |
| Grafana | `docker.io/grafana/grafana:10.3.0` | Visualization |
| Node Exporter | `docker.io/prom/node-exporter:v1.7.0` | Host metrics |
| Kube State Metrics | `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.1` | K8s metrics |
| Prometheus Operator | `quay.io/prometheus-operator/prometheus-operator:v0.71.0` | Operator |
| Prometheus Config Reloader | `quay.io/prometheus-operator/prometheus-config-reloader:v0.71.0` | Config reloader |

**Sources:**
- [Prometheus Docker Hub](https://hub.docker.com/r/prom/prometheus)
- [Grafana Docker Hub](https://hub.docker.com/r/grafana/grafana)
- [kube-state-metrics GitHub](https://github.com/kubernetes/kube-state-metrics)

## Kiali (Istio Observability)

**Official Registry:** Quay.io

| Component | Public Image | Notes |
|-----------|-------------|-------|
| Kiali | `quay.io/kiali/kiali:v1.79.0` | Service mesh UI |
| Kiali Operator | `quay.io/kiali/kiali-operator:v1.79.0` | Operator |

## Version Notes

- **Istio:** v1.20.0 (stable as of Feb 2026)
- **ArgoCD:** v2.10.0 (stable as of Feb 2026)
- **Monitoring:** Compatible with Big Bang 2.19.0

## How to Use This Mapping

When overriding Big Bang values, use these patterns:

```yaml
# Istio example
istio:
  values:
    global:
      hub: docker.io/istio
      tag: 1.20.0

# ArgoCD example
argocd:
  values:
    global:
      image:
        repository: quay.io/argoproj/argocd
        tag: v2.10.0

# Prometheus example
monitoring:
  values:
    prometheus:
      prometheusSpec:
        image:
          registry: docker.io
          repository: prom/prometheus
          tag: v2.50.0
```

## Important Considerations

1. **Version Compatibility:** Ensure public image versions match or are compatible with Big Bang's expectations
2. **Security:** Public images may not have the same hardening as Iron Bank images
3. **Support:** Iron Bank provides security scanning and compliance - public images are "as-is"
4. **Architectures:** Verify multi-arch support if running on ARM (Apple Silicon)

## Next Steps

1. Review Big Bang's `values.yaml` to find exact image paths
2. Override each image reference in `bigbang/values/sandbox.yaml`
3. Test with `helm template` before deploying
4. Monitor image pulls during deployment

---

**Last Updated:** 2026-02-11
**Big Bang Version:** 2.19.0
**Purpose:** Sandbox/learning environment without Iron Bank access

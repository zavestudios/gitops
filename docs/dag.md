# GitOps Execution DAG (Flux + BigBang + Helm)

This deployment follows a directed, acyclic execution chain.  
Each node reconciles only after its upstream dependencies stabilize.

## DAG

Git Repository State  
↓  
Flux GitRepository reconciliation  
↓  
BigBang HelmRelease (root configuration input)  
↓  
BigBang values merge and normalization  
  - merges ConfigMap values with chart defaults  
  - injects platform-wide policies (registries, globals, etc.)  
↓  
BigBang templates generate deployment resources  
  - renders HelmRelease objects for packages  
  - renders supporting Secrets/ConfigMaps  
↓  
Flux reconciles generated HelmRelease objects  
↓  
Helm renders each package chart  
  - merges package values with upstream defaults  
  - executes templates  
↓  
Kubernetes applies resulting manifests  

## Debugging Principle

Always start at the highest upstream node that could influence behavior.

Configuration flows downward through the DAG.  
Rendered manifests are outputs, not inputs.

## Practical Inspection Order

1. Git commit / branch / tag state  
2. Flux GitRepository status  
3. BigBang HelmRelease values  
4. BigBang merged values and generated resources  
5. Package HelmRelease values  
6. Package Helm render output  
7. Final Kubernetes resources


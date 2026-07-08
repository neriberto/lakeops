## Title

Explicit `destinations` and tightened RBAC whitelists (not `server: '*'`)

> **Status:** Accepted
>
> **Date:** 2026-07-07

## Context

ArgoCD AppProjects enforce two distinct boundaries: the **destination**
boundary (which clusters and namespaces may an Application target) and the
**RBAC** boundary (which Kubernetes resource kinds may the Applications inside
the project create). Both boundaries must be intentionally tight. Defaulting
either to `*` invites a misconfigured cluster registration, a stray Helm
template, or a chart with an overly broad RBAC footprint to escalate.

In particular, `spec.destinations` containing `server: '*'` and
`namespace: '*'` is the path of least resistance — it lets every Application
target every cluster and every namespace. That posture is appropriate for
exploration but not for a platform that other engineers will deploy to.

## Decision

`destinations` is an explicit, enumerated list of `(server, namespace)` pairs
in [`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml):35-44.
The three entries today are identical (local dev, stage, prod all point at
the in-cluster ArgoCD endpoint `https://kubernetes.default.svc`), which is
the right shape while every environment lives on the same cluster;
[RFC-0001](../rfc/0001-destination-allowlist-uniformity.md) proposes how to
evolve the shape when stage and prod move to dedicated clusters. The list is
**not** keyed per project: the template at
[`apps/appprojects/templates/appproject.yaml`](../../apps/appprojects/templates/appproject.yaml):21-22
renders the same block into every AppProject, so all three categories share
an identical allowlist by construction.

RBAC whitelists are also explicit. `clusterResourceWhitelist` (lines 46-54)
is restricted to `Namespace`, `PersistentVolume`, `ClusterRole`, and
`ClusterRoleBinding`. `namespaceResourceWhitelist` (lines 56-108) enumerates
each supported `kind` (Deployment, StatefulSet, Service, Ingress, Secret, and
so on) by API group. There is no `*` wildcard. A new resource kind — for
example, a `Gateway` from the Gateway API — requires an explicit addition to
the whitelist; this is a deliberate forcing function.

The namespace-resource whitelist deliberately excludes cluster-scoped kinds
that should never be created by workloads (for example, `CustomResourceDefinition`,
`MutatingWebhookConfiguration`). Those live, if anywhere, in operator
charts that are managed separately from this GitOps repo.

## Consequences

- A misconfigured ArgoCD cluster registration pointing at an unapproved
  cluster cannot be exploited by any Application: the AppProject's
  `destinations` list will refuse the target.
- A chart that introduces a new resource kind fails visibly on first sync
  ("resource kind X is not permitted in project Y") rather than silently
  creating it.
- The whitelist is verbose but explicit. Diffing a change to the whitelist
  shows exactly which kinds are being granted or revoked.
- Adding a new cluster requires editing `destinations` and re-rendering.
  This is the intentional cost; see [RFC-0001](../rfc/0001-destination-allowlist-uniformity.md)
  for the proposed shape once multiple clusters are in play.

## Alternatives Considered

- **`server: '*'` / `namespace: '*'`.** Convenient for a single-cluster setup
  but collapses the destination boundary; one stray `argocd cluster add` and
  every Application can target the new cluster.
- **Kustomize-based RBAC patches per AppProject.** Reproduces the drift
  problem [ADR-0001](0001-appprojects-helm-rendered.md) was designed to
  eliminate: the same RBAC list maintained in three places.
- **OPA / Kubernetes RBAC for ArgoCD policy.** More powerful but
  meaningfully more complex; appropriate when the AppProject allowlist
  becomes a bottleneck, which is not yet the case.

## References

- [ADR-0001 — AppProjects generated from a Helm chart](0001-appprojects-helm-rendered.md)
- [ADR-0003 — Three-tier workload categorization](0003-three-tier-categorization.md)
- [RFC-0001 — Destination allowlist uniformity](../rfc/0001-destination-allowlist-uniformity.md)
- [`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml):35-44 (`destinations`), :46-108 (whitelists)
- [`apps/appprojects/templates/appproject.yaml`](../../apps/appprojects/templates/appproject.yaml):21-22
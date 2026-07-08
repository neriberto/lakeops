## Title

Per-environment ApplicationSets targeting in-cluster microk8s

> **Status:** Accepted
>
> **Date:** 2026-07-07

## Context

Every environment (`dev`, `stage`, `prod`) deploys its own copy of each
component into its own namespace (`{component}-{env}`). The set of components
differs across environments today (only `dev` has elements defined), and the
Helm value overrides also differ. Two structural choices were available:

1. **One mega-ApplicationSet with a per-env filter.** Simpler path layout but
   harder to evolve — adding a new env or splitting a component into a
   multi-cluster pattern requires restructuring the generator.
2. **Per-environment ApplicationSets, one per `apps/{env}/appset.yaml`.** Each
   file is self-contained; new environments are additive.

In addition, the cluster topology question — a single Kubernetes cluster
for everything, or per-env clusters — has to be reflected in the
`destination.server` field of every generated `Application`.

## Decision

There is one ApplicationSet per environment, located at
[`apps/dev/appset.yaml`](../../apps/dev/appset.yaml) (and the stage and prod
siblings). Each uses a `list` generator with one element per component and
the following fixed shape:

```yaml
spec:
  generators:
    - list:
        elements:
          - chart: seaweedfs
            namespace: seaweedfs-dev
            project: infrastructure
            syncWave: -2
  template:
    metadata:
      name: "{{ .chart }}-dev"
      ...
    spec:
      project: "{{ .project }}"
      sources:
        - repoURL: https://seaweedfs.github.io/seaweedfs/helm
          chart: "{{ .chart }}"
          targetRevision: 4.36.0
          helm:
            releaseName: "{{ .chart }}"
            valueFiles:
              - "$values/apps/values/dev/{{ .chart }}.yaml"
        - repoURL: https://github.com/neriberto/lakeops
          targetRevision: main
          ref: values
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{ .namespace }}"
```

Three properties follow:

1. **`destination.server` is the in-cluster ArgoCD endpoint** (`https://kubernetes.default.svc`)
   for every Application today. The ArgoCD control plane runs on the same
   cluster the Applications deploy into. This works on any conformant
   Kubernetes distribution — microk8s, EKS, GKE, k3s, kind — because the
   in-cluster DNS name resolves identically in each. [RFC-0004](../rfc/0004-multi-cluster-progression.md)
   proposes the hub-and-spoke topology that supersedes this.
2. **`goTemplate: true`** enables `{{ }}` interpolation in the template
   fields. Without it the generators would have to use legacy `$value`
   substitution, which is less readable and harder to debug.
3. **The `values` source ref** reads per-environment Helm overrides from
   `apps/values/{env}/{component}.yaml` (see
   [`docs/adding-a-new-application.md`](../adding-a-new-application.md)).

The bootstrap Application that creates each ApplicationSet lives at
[`apps/bootstrap/dev.yaml`](../../apps/bootstrap/dev.yaml) (and siblings) and
references `apps/dev/` as its source path.

## Consequences

- Adding a component to dev is a 4-line addition to `apps/dev/appset.yaml`
  plus a values file. No other file in the bootstrap chain has to change.
- Each env's appset is independently visible in the ArgoCD UI; failures
  surface per-environment rather than as a single monolithic diff.
- The in-cluster `destination.server` couples every Application to the
  cluster ArgoCD runs on. When stage and prod move to separate clusters, the
  field will change for those envs and `appset-stage`/`appset-prod` will need
  to be revisited (see [RFC-0004](../rfc/0004-multi-cluster-progression.md)).
- The `syncWave` field per element expresses intra-environment ordering
  (storage → platform → workloads) without coupling to the bootstrap
  AppProject sync-wave; see [ADR-0002](0002-app-of-apps-sync-waves.md).

## Alternatives Considered

- **Single ApplicationSet with a `cluster` generator.** Would generate
  Applications for every env in one manifest, at the cost of an extra
  generator dimension and more complex per-env value-file selection.
- **`Application` per component (no ApplicationSet).** Maximally explicit but
  every component add is a new file under `apps/bootstrap/`; the list
  generator pattern scales better.
- **Kustomize-based per-env overlays of a single base ApplicationSet.**
  Reasonable but adds Kustomize to the toolchain when Helm is already
  present for the chart ecosystem.

## References

- [ADR-0001 — AppProjects generated from a Helm chart](0001-appprojects-helm-rendered.md)
- [ADR-0002 — App-of-apps bootstrap with explicit sync waves](0002-app-of-apps-sync-waves.md)
- [RFC-0004 — Multi-cluster ArgoCD topology](../rfc/0004-multi-cluster-progression.md)
- [`apps/dev/appset.yaml`](../../apps/dev/appset.yaml)
- [`apps/bootstrap/dev.yaml`](../../apps/bootstrap/dev.yaml)
- [`docs/adding-a-new-application.md`](../adding-a-new-application.md)

## Note on portability (added 2026-07-07)

This ADR was accepted when every environment ran on a single microk8s
instance; the title reflects that historical state and is preserved
per the repository's immutability convention.

The decision itself — one ApplicationSet per environment at
`apps/{env}/appset.yaml` — is **distribution-agnostic**. The
`destination.server` value used by every generated Application
(`https://kubernetes.default.svc`) is the in-cluster ArgoCD endpoint
and resolves identically on microk8s, EKS, GKE, k3s, kind, and any
other conformant Kubernetes distribution. The Applications in this
repository do not depend on microk8s-specific behavior.

When stage and prod move to dedicated clusters, the topology
evolves per [RFC-0004](../rfc/0004-multi-cluster-progression.md);
this ADR remains the record of the *single-cluster* era.
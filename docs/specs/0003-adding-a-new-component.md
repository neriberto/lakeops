## Title

Adding a new component to an environment

> **Status:** Implemented
>
> **Date:** 2026-07-07
>
> **Author(s):** lakeops maintainers

## Overview

This spec codifies the contract that
[`docs/adding-a-new-application.md`](../adding-a-new-application.md)
implements. That document is the hands-on, copy-paste-ready guide with
worked examples for PostgreSQL and Trino; this spec is the rationale — the
inputs, outputs, and conventions that make the workflow work.

Registering a new component in an environment is the same operation
regardless of which Helm chart is involved. The operator writes a values
override file at `apps/values/{env}/{component}.yaml`, adds one element to
the per-environment ApplicationSet generator at
`apps/{env}/appset.yaml`, and commits. ArgoCD generates an Application
named `{component}-{env}` that owns the namespace `{component}-{env}` and
inherits the appropriate AppProject's RBAC and destination allowlist. No
new file under `apps/bootstrap/` is required.

## Architecture

The input contract is two files; the output is one ArgoCD `Application`.

```mermaid
graph LR
  V[apps/values/{env}/{component}.yaml<br/>Helm overrides] --> AS[apps/{env}/appset.yaml<br/>generator element]
  AS -->|generates| A[Application<br/>name: '{component}-{env}']
  A -->|deploys| N[namespace: '{component}-{env}']
  A -->|inherits| P[AppProject<br/>infrastructure / platform / workloads]
  A -->|sync wave| W[argocd.argoproj.io/sync-wave: '{N}']
```

The values file is read by ArgoCD as a Helm values overlay at apply time.
The generator element is the per-component configuration the ApplicationSet
expands into a full `Application` resource. The chart repository must
already be in the AppProject's `sourceRepos` allowlist; adding a new
repository requires a values.yaml edit and a re-render (see
[SPEC-0001](0001-appproject-helm-chart-and-rendered-pattern.md)).

## Components

### Generator element fields

Each element in the per-environment ApplicationSet generator supports four
fields. All four are required for new components.

| Field | Required | Description |
| --- | --- | --- |
| `chart` | yes | Helm chart name, also used as the Application name suffix (`{chart}-{env}`) and the release name inside the namespace. |
| `namespace` | yes | Target Kubernetes namespace. The convention is `{component}-{env}`. |
| `project` | yes | ArgoCD AppProject: `infrastructure`, `platform`, or `workloads`. The `project` field on the generated Application is the one gate ArgoCD enforces for source repos and destination allowlist. |
| `syncWave` | yes | ArgoCD sync wave. Negative values run before the default; positive values run after. Foundation components use negative waves; downstream datalake workloads use positive waves. |

The element is interpolated by the ApplicationSet template into the
generated `Application` manifest via `goTemplate: true` (see
[`apps/dev/appset.yaml`](../../apps/dev/appset.yaml)). The `sources` block
on the generated Application reads the per-component values file with a
`$values/apps/values/{env}/{component}.yaml` ref, which means every
component's values file lives next to the bootstrap layer and is versioned
with the rest of the repository.

### AppProject selection

The `project` field maps directly to one of the three AppProjects defined
in [SPEC-0001](0001-appproject-helm-chart-and-rendered-pattern.md). The
mapping rule is:

| Component role | AppProject | Examples |
| --- | --- | --- |
| Foundational services (storage, networking, ingress, monitoring) | `infrastructure` | SeaweedFS, Nginx Ingress, MetalLB, cert-manager |
| Shared data-layer dependencies (databases, message buses, secrets) | `platform` | PostgreSQL, Redis, Kafka, Vault, Keycloak |
| Datalake and analytics workloads | `workloads` | Airflow, Trino, Spark, Nessie, Metabase, Superset, JupyterHub |

The selection is enforced at Application admission time: ArgoCD refuses to
create an Application whose `project` field names an AppProject that
denies the requested `sourceRepos` or `destinations`. A new chart
repository that is not in the AppProject's `sourceRepos` list fails
immediately rather than silently deploying.

## Implementation

The decision tree for a new component has three branches. Each branch
produces the same file changes (one new values file, one new generator
element); only the values of the fields differ.

**1. Pick the project.** Classify the component by role. Storage,
networking, ingress, monitoring, and certificates belong in `infrastructure`.
Shared data-layer services consumed by more than one workload belong in
`platform`. Datalake and analytics workloads belong in `workloads`. The
selection is part of the contract; re-categorization is rare and should be
called out in a commit message.

**2. Pick the namespace.** The convention is `{component}-{env}`. The
generated Application sets `destination.namespace: {namespace}` and the
ApplicationSet template propagates the value to every Helm release. The
bootstrap Application that owns the ApplicationSet sets
`CreateNamespace=true`, so the namespace is auto-created on first sync
without an explicit `Namespace` resource in the values file.

**3. Pick the sync wave.** Foundation components that other components
depend on (storage, databases) use a negative wave so they reconcile
first. Default and parallel-safe components use `0`. Datalake workloads
that depend on the data layer use a positive wave so they reconcile after
their dependencies. Today the in-cluster destinations are identical, so
the wave is informational; once stage and prod move to separate clusters
(see [RFC-0004](../rfc/0004-multi-cluster-progression.md)) the wave
becomes load-bearing.

After the three decisions, the registration is a two-file change:

1. Create `apps/values/{env}/{component}.yaml` with the Helm overrides
   for the new chart.
2. Add one element to the `generators[0].list.elements` array in
   `apps/{env}/appset.yaml` with `chart`, `namespace`, `project`, and
   `syncWave` set per the decision tree above.

Commit both files. ArgoCD's auto-sync picks up the ApplicationSet diff on
the next reconciliation and emits the per-component Application. No
`kubectl apply` is required for routine additions; the wave-`0` bootstrap
Application is the only `Application` resource the operator ever applies
by hand for a given environment.

## Verification

The end state of a successful registration is testable from the cluster
API and the ArgoCD CLI.

The generated Application reaches `Synced/Healthy`:

```bash
kubectl get application -n argocd {component}-{env}
```

The expected output is `Synced/Healthy`. A `Missing` or `Unknown` status
usually means the AppProject does not allow the chart's source repository
or the destination namespace — see the troubleshooting section of
[`docs/adding-a-new-application.md`](../adding-a-new-application.md).

The namespace exists and contains the chart's resources:

```bash
kubectl get namespace {component}-{env}
kubectl get all -n {component}-{env}
```

The namespace is created automatically by `CreateNamespace=true` on the
bootstrap Application; no explicit `Namespace` resource is required.

The Application was generated by the ApplicationSet (not applied by hand):

```bash
kubectl get application -n argocd {component}-{env} \
  -o jsonpath='{.metadata.ownerReferences[0].name}'
```

The owner reference must point at `appset-{env}`. A missing or different
owner reference means the Application was registered outside the
ApplicationSet and will not inherit the per-component sync options.

The AppProject allowlist accepted the chart repository. If the
component's chart is not in the AppProject's `sourceRepos`, ArgoCD
rejects the Application at admission time with a `Forbidden` condition.
The fix is to add the repository to
[`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml),
regenerate the rendered AppProjects (see
[SPEC-0001](0001-appproject-helm-chart-and-rendered-pattern.md)), and
re-commit.

## References

- [ADR-0003 — Three-tier workload categorization](../adr/0003-three-tier-categorization.md)
- [ADR-0005 — Per-environment ApplicationSets](../adr/0005-per-environment-applicationsets.md)
- [RFC-0001 — Destination allowlist uniformity across AppProjects](../rfc/0001-destination-allowlist-uniformity.md)
- [SPEC-0001 — AppProject Helm chart and rendered output contract](0001-appproject-helm-chart-and-rendered-pattern.md)
- [SPEC-0002 — Bootstrap flow and sync-wave ordering](0002-bootstrap-flow.md)
- [`docs/adding-a-new-application.md`](../adding-a-new-application.md) — hands-on guide with worked examples
- [`apps/dev/appset.yaml`](../../apps/dev/appset.yaml)
- [`apps/bootstrap/dev.yaml`](../../apps/bootstrap/dev.yaml)

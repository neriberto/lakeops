## Title

Three-tier workload categorization (infrastructure / platform / workloads)

> **Status:** Accepted
>
> **Date:** 2026-07-07

## Context

The `lakeops` platform runs a heterogeneous mix of workloads: object storage
(SeaweedFS), ingress controllers, PostgreSQL, Redis, Kafka, Airflow, Trino,
Spark, Nessie, Metabase, Superset, JupyterHub. Without a taxonomy, every new
component requires an ad-hoc decision about which AppProject (and therefore
which RBAC whitelist and which destination allowlist) it inherits from, and
the platform's surface area grows incoherently.

The categories must satisfy three properties: (1) they cover every workload
without overlap, (2) they reflect the actual dependencies between components
(storage → data layer → analytics), and (3) they are stable — adding a new
component should not force a re-categorization.

## Decision

Workloads are partitioned into three AppProject categories, defined as the
`.Values.projects` entries in
[`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml):114-120:

| Project        | Role                                                                                | Examples                                         |
| -------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------ |
| `infrastructure` | Foundational services the platform and workloads depend on (storage, networking).   | SeaweedFS, Nginx Ingress, MetalLB, cert-manager. |
| `platform`     | Shared data-layer dependencies consumed by multiple workloads.                     | PostgreSQL, Redis, Kafka, Vault, Keycloak.       |
| `workloads`    | The datalake / lakehouse workloads themselves — the analytics surface area.        | Airflow, Trino, Spark, Nessie, Metabase, Superset, JupyterHub. |

The dependency direction runs `infrastructure → platform → workloads`:
infrastructure components (storage, networking) are prerequisites for the
data layer, which is in turn a prerequisite for the workloads. This direction
is enforced at sync-wave granularity inside each environment's ApplicationSet
(negative waves for infrastructure, positive for workloads).

The `platform` AppProject deliberately includes `kind: Secret` in its
namespace-resource whitelist (see
[`values.yaml`](../../apps/appprojects/values.yaml):80) because secrets are a
data-layer concern. A future secrets-management strategy will live inside the
`platform` category; see [RFC-0002](../rfc/0002-secrets-management.md).

## Consequences

- Every new component maps to exactly one of the three categories. The
  mapping is documented in
  [`docs/adding-a-new-application.md`](../adding-a-new-application.md):222-228
  and is enforced by the `project` field required in every ApplicationSet
  generator element.
- The three AppProjects share identical `sourceRepos`, `destinations`, and
  RBAC whitelists — only the name and description vary. This is structural,
  not aspirational; see [ADR-0001](0001-appprojects-helm-rendered.md).
- Cross-tier dependencies (a workload reading from PostgreSQL) traverse
  namespaces, not AppProjects. AppProjects are an ArgoCD-side RBAC concept;
  Kubernetes networking and service discovery are unaffected.
- Introducing a fourth category (for example, a `security` tier for Vault
  and cert-manager) is a single line in `.Values.projects` plus a re-render.

## Alternatives Considered

- **Flat single AppProject.** Simpler bootstrap, but every component inherits
  every allowlist, and a misconfigured `sourceRepos` would let any workload
  pull from an unintended chart repository.
- **Per-component AppProject.** Maximum isolation, but explodes the bootstrap
  surface area (AppProjects themselves become a meaningful operational
  artifact per component) and provides no categorial signal.
- **Two tiers (`infra` / `workloads`).** Hides the data-layer distinction:
  PostgreSQL and SeaweedFS end up in the same category despite very different
  RBAC needs and lifecycle profiles. Three tiers is the smallest split that
  keeps the data layer explicit.

## References

- [ADR-0001 — AppProjects generated from a Helm chart](0001-appprojects-helm-rendered.md)
- [ADR-0004 — Defense-in-depth AppProject configuration](0004-defense-in-depth-appproject-config.md)
- [RFC-0002 — Secrets management strategy](../rfc/0002-secrets-management.md)
- [`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml)
- [`docs/adding-a-new-application.md`](../adding-a-new-application.md)
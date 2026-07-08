# Architecture Decision Records

This directory holds Architecture Decision Records (ADRs) for the `lakeops`
GitOps repository. Each ADR captures one significant technical decision: the
context that motivated it, the choice we made, the trade-offs we accepted, and
the alternatives we considered. ADRs are immutable once accepted; superseding
a decision means writing a new ADR that references the old one.

## Status legend

| Status      | Meaning                                                             |
| ----------- | ------------------------------------------------------------------- |
| Accepted    | The decision is in force and reflected in the current code and YAML. |
| Superseded  | Replaced by a newer ADR. The superseding ADR is linked in References. |
| Deprecated  | No longer relevant but kept for historical context. No replacement.  |

## Index

1. [0001 — AppProjects generated from a Helm chart with committed `rendered/` manifests](0001-appprojects-helm-rendered.md)
2. [0002 — App-of-apps bootstrap with explicit sync waves (`-10` / `0`)](0002-app-of-apps-sync-waves.md)
3. [0003 — Three-tier workload categorization (infrastructure / platform / workloads)](0003-three-tier-categorization.md)
4. [0004 — Explicit `destinations` and tightened RBAC whitelists (not `server: '*'`)](0004-defense-in-depth-appproject-config.md)
5. [0005 — Per-environment ApplicationSets targeting in-cluster Kubernetes](0005-per-environment-applicationsets.md)
6. [0006 — CI drift-check + pre-commit hook to keep `rendered/` in sync with chart source](0006-rendered-drift-ci-precommit.md)
7. [0007 — ~~Bitnami PostgreSQL Helm chart for the platform foundation (`dev`)~~](0007-bitnami-postgresql-chart-for-platform-foundation.md) **(Superseded by [ADR-0009](0009-cloudnative-pg-for-platform-data-layer.md))**
8. [0008 — Sealed Secrets for `dev` and `stage`; defer ESO to `prod` via RFC-0004](0008-sealed-secrets-for-dev-and-stage.md)
9. [0009 — Adopt CloudNativePG for the platform data layer; supersede ADR-0007](0009-cloudnative-pg-for-platform-data-layer.md)

## Authoring a new ADR

Use filename pattern `NNNN-short-title.md` (zero-padded 4-digit ID, lowercase,
hyphen-separated). Use the Nygard template — Title, Status, Date, Context,
Decision, Consequences, Alternatives Considered, References — with relative
paths for cross-references.
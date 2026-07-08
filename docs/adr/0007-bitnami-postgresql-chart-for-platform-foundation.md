## Title

Bitnami PostgreSQL Helm chart for the platform foundation (`dev`); Zalando and CloudNativePG deferred to RFC-0004 multi-cluster HA work

> **Status:** Superseded by [ADR-0009](0009-cloudnative-pg-for-platform-data-layer.md)
>
> **Date:** 2026-07-08

## Context

PostgreSQL is Phase 0 — Foundation in the rollout sequence proposed by
[RFC-0005](../rfc/0005-initial-workload-rollout-sequence.md) and lives in the
`platform` AppProject per the three-tier categorization in
[ADR-0003](../adr/0003-three-tier-categorization.md). Every analytics workload
in Phase 1+ (Nessie, Metabase, Airflow, JupyterHub) depends on it for
relational metadata, so installing PostgreSQL first is the lowest-risk
foundation: all later phases are guaranteed to find a real Postgres to
connect to.

Three viable Helm-based options exist for the PostgreSQL workload: the
[Bitnami `postgresql` chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql),
the [Zalando postgres-operator](https://github.com/zalando/postgres-operator),
and [CloudNativePG](https://cloudnative-pg.io). The decision has to balance
"lowest operational overhead for `dev`" against "ability to graduate the same
operator to `stage` / `prod`" once RFC-0004 multi-cluster HA work lands. The
worked example in [`docs/adding-a-new-application.md`](../adding-a-new-application.md)
§Example A has already committed the platform to the Bitnami chart — the
chart repo, the values-file shape, and the ApplicationSet entry — without
recording why we chose it over Zalando or CloudNativePG. This ADR closes that
trace gap.

## Decision

We adopt the Bitnami PostgreSQL Helm chart for `dev`, sourced from
`https://charts.bitnami.com/bitnami`. The values-file shape and the
ApplicationSet entry follow the worked example in
[`docs/adding-a-new-application.md`](../adding-a-new-application.md)
§Example A; the chart repo is added to `apps/appprojects/values.yaml`
`sourceRepos` and the AppProjects re-rendered per
[ADR-0001](../adr/0001-appprojects-helm-rendered.md) and
[ADR-0006](../adr/0006-rendered-drift-ci-precommit.md).

Zalando postgres-operator and CloudNativePG are explicitly **deferred** to
the multi-cluster HA work tracked by
[RFC-0004](../rfc/0004-multi-cluster-progression.md). When `stage` and
`prod` graduate beyond a single-node `dev` cluster, RFC-0004 will re-evaluate
both options and the platform may switch operators at that point.

## Consequences

- `apps/appprojects/values.yaml` `sourceRepos` gains the Bitnami repo
  (`https://charts.bitnami.com/bitnami`). The change follows the
  ADR-0001 render-and-commit pattern: re-render AppProjects with
  `bash scripts/render-appprojects.sh` and commit both the values file and
  the matching `apps/appprojects/rendered/*.yaml` outputs, enforced by the
  CI drift-check and pre-commit hook from
  [ADR-0006](../adr/0006-rendered-drift-ci-precommit.md).
- `apps/values/dev/postgresql.yaml` follows the values pattern in
  §Example A: single primary, `metrics.enabled: false` by default,
  `storageClass: ""` to defer to the cluster default, and explicit
  `requests` (256Mi memory / 250m CPU) to keep the `dev` footprint small.
- `stage` and `prod` will diverge from `dev` once RFC-0004 lands. The
  eventual `apps/values/{stage,prod}/postgresql.yaml` files will track
  whichever operator RFC-0004 settles on (Zalando or CloudNativePG), and
  the `sourceRepos` allowlist will gain that operator's chart repo. This
  ADR does not constrain that future choice.
- `metrics.enabled` stays `false` by default. PostgreSQL exposes a
  Prometheus endpoint via the chart's `metrics` block, but enabling it on
  `dev` adds a sidecar without a corresponding scraper; flipping the toggle
  is a one-line values-file change once a Prometheus stack lands in
  `platform`.
- Implementing the decision — writing `apps/values/dev/postgresql.yaml`,
  editing `apps/appprojects/values.yaml` `sourceRepos`, editing
  `apps/dev/appset.yaml`, and re-rendering the AppProjects — is
  **intentionally out of scope for this ADR.** This ADR records *what was
  decided and why*; the implementation commit lands separately so that the
  trace artifact is reviewable on its own.

## Alternatives Considered

- **Zalando postgres-operator.** Deferred to RFC-0004. The operator pattern
  adds a CRD, a controller, and a per-cluster `Postgres` resource —
  operational overhead that is not warranted for a single-node `dev`
  cluster. Zalando is the most likely candidate when RFC-0004 picks an
  operator for `stage` and `prod` because of its mature failover story.
- **CloudNativePG** ([cloudnative-pg.io](https://cloudnative-pg.io)). Deferred to RFC-0004.
  Same reasoning as Zalando: operator complexity not warranted for `dev`,
  but CloudNativePG is a strong candidate for `prod` because of its
  first-class `kubectl` integration and declarative `Cluster` resource.
  The choice between Zalando and CloudNativePG is itself a future RFC-0004
  decision.
- **Bitnami `postgresql-ha` subchart.** Deferred to RFC-0004 alongside the
  operator question. The HA subchart adds a replication topology (primary
  + read replicas + replication slots) that microk8s-on-a-laptop cannot
  usefully exercise; revisit when `stage` needs real HA.
- **Embedded per-workload PostgreSQL** (CloudNativePG or similar inside
  each consuming namespace). Rejected: this duplicates operational work,
  defeats the purpose of a shared `platform` AppProject, and creates
  backup sprawl. Already rejected by [RFC-0005](../rfc/0005-initial-workload-rollout-sequence.md)
  §Alternatives Considered.

## References

- [ADR-0001 — AppProjects generated from a Helm chart with committed `rendered/` manifests](../adr/0001-appprojects-helm-rendered.md)
- [ADR-0003 — three-tier categorization places PostgreSQL in `platform`](../adr/0003-three-tier-categorization.md)
- [ADR-0006 — CI drift-check + pre-commit pattern used to keep `rendered/` AppProjects in sync after adding `sourceRepos`](../adr/0006-rendered-drift-ci-precommit.md)
- [RFC-0004 — multi-cluster HA work; Zalando and CloudNativePG will be re-evaluated here for `stage` / `prod`](../rfc/0004-multi-cluster-progression.md)
- [RFC-0005 — places PostgreSQL in Phase 0 (Foundation); the Bitnami pick was first recommended in this RFC's §Open Questions](../rfc/0005-initial-workload-rollout-sequence.md)
- [SPEC-0003 — registration contract every new component follows; the worked PostgreSQL example in §Example A is the implementation template](../specs/0003-adding-a-new-component.md)
- [`docs/adding-a-new-application.md` — §Example A is the worked example that has committed the platform to the Bitnami chart](../adding-a-new-application.md)
- [ADR-0009 — CloudNativePG for the platform data layer](../adr/0009-cloudnative-pg-for-platform-data-layer.md) — supersedes this ADR; CloudNativePG operator + Cluster CR is the binding decision.

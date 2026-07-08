## Title

Pin the CloudNativePG operator chart version, the wrapper chart version, and the Postgres major version; record the upgrade procedure for the platform data layer.

> **Status:** Draft
>
> **Date:** 2026-07-08
>
> **Author(s):** lakeops maintainers

## Overview

The CloudNativePG operator chart is a rolling artifact. Upstream
[`charts/cloudnative-pg/Chart.yaml`](https://github.com/cloudnative-pg/charts)
on `main` declares `version: 0.29.0` for the operator chart itself and
`appVersion: "1.30.0"` for the operator's controller-manager. The `Cluster`
CR at [`apps/cloudnative-pg/clusters/postgresql.yaml`](../../apps/cloudnative-pg/clusters/postgresql.yaml)
is rendered directly as plain YAML by a standalone ArgoCD `Application`
at [`apps/cloudnative-pg/clusters/application.yaml`](../../apps/cloudnative-pg/clusters/application.yaml);
the wrapper-chart pattern from the planner pass was rejected per
[ADR-0009](../adr/0009-cloudnative-pg-for-platform-data-layer.md)
§Decision — there is no wrapper chart on disk today. The `Cluster`
CR's `spec.postgresqlVersion` decides which PostgreSQL container image
the operator pulls (currently `"17"`). All three pins move on independent
cadences; a half-pinned surface can still silently drift on the unpinned
axis.

This spec pins three layers: (a) the operator chart version in the
ApplicationSet element that deploys it (`apps/dev/appset.yaml`, today
`version: 0.29.0`); (b) a wrapper chart version reserved at `0.1.0` for
the eventual wrapper-chart pattern (see §Architecture / Contract bullet 2
— not currently bound to any on-disk file); (c) `Cluster.spec.postgresqlVersion`
(today `"17"`). The §Implementation / §Procedure below is the upgrade
playbook for the operator-chart axis and the `postgresqlVersion` axis;
the wrapper-chart axis is reserved until a chart exists.

Why all three pins matter: an unpinned operator chart follows upstream
`latest` and silently refetches a new release into `dev`; an unpinned
`postgresqlVersion` lets the operator's own default take over and skips
the PostgreSQL-major-version reviews this spec's Pattern X is designed to gate; an
unreserved wrapper-chart pin would let the future chart drift across
its own bump. §Implementation / §Procedure step 6 verifies the
on-cluster result matches the pins after every bump.

## Architecture / Contract

The pinning contract is five bullets. Each is enforceable from the
repository state alone; no live cluster is required.

- **Operator chart version pinned via the `version` field on the
  `cloudnative-pg` ApplicationSet generator element** at
  [`apps/dev/appset.yaml`](../../apps/dev/appset.yaml). Today's pin is
  **`0.29.0`**. Bumping the pin is a one-line edit on the element; the
  install lands via ArgoCD on the next reconcile. Future environments
  (`apps/stage/appset.yaml`, `apps/prod/appset.yaml`) carry their own pins
  once they exist.
- **Wrapper chart version (reserved).** If a future wrapper chart wraps
  one or more `Cluster` CRs (for example to emit a multi-Cluster manifest,
  or to compose the `Pooler` resource alongside the Cluster), the wrapper
  chart's `Chart.yaml` `version` field is the pin. The reserved initial
  pin is **`0.1.0`** (not currently bound to any on-disk file —
  [ADR-0009](../adr/0009-cloudnative-pg-for-platform-data-layer.md)
  §Decision rejects the wrapper chart for the single-Cluster case). The
  chart's `appVersion` field, if the chart lands, mirrors the upstream
  operator `appVersion` (currently `"1.30.0"`) as a documentation string.
- **`Cluster.spec.postgresqlVersion: "17"`** — pinned string in the rendered
  `Cluster` CR at
  [`apps/cloudnative-pg/clusters/postgresql.yaml`](../../apps/cloudnative-pg/clusters/postgresql.yaml).
  The pin is a string per the upstream `Cluster` CR schema and ArgoCD
  reconciles it as a plain manifest (no Helm templating today; see
  §Components paragraph 2). **Major-version upgrades require an RFC**, not
  a spec update — the `postgresqlVersion` major boundary is the trigger
  for heavier-weight change-control per the pattern this spec follows.
- **No automatic bumping.** No Renovate / Dependabot automation lives in
  this repository. Every chart or `postgresqlVersion` bump is a reviewed PR
  that runs the offline validation chain (§Implementation / §Procedure
  step 4) and observes the cluster in step 6 before merge. Auto-merge
  rules are explicitly disallowed on this path.
- **Upgrade cadence.** Quarterly minor upgrades for `dev` only. `stage` and
  `prod` lag `dev` by one cycle (so `stage` lands ~one quarter after
  `dev`, `prod` lands ~one quarter after `stage`). Major `postgresqlVersion`
  bumps (e.g., `17` → `18`) require a PostgreSQL-major-upgrade RFC and a
  logical export / import on `stage` and `prod`. The wrapper chart's
  `version` field is bumped on per-environment values changes per SPEC-0001;
  the operator chart's `version` field is bumped quarterly for `dev` and
  follows the same lag.

## Components

The implementation surfaces are four concrete files plus the rendered
ArgoCD `Application` output that ArgoCD reconciles.

The `cloudnative-pg-dev` Application is generated by the ApplicationSet at
[`apps/dev/appset.yaml`](../../apps/dev/appset.yaml). The `cloudnative-pg`
element carries `repoURL: https://cloudnative-pg.github.io/charts`,
`chart: cloudnative-pg`, `version: 0.29.0`, `namespace: cloudnative-pg-dev`,
`project: infrastructure`, `syncWave: -2`. The `project: infrastructure`
placement is intentional — the operator install is a foundation-tier
component per [ADR-0003](../adr/0003-three-tier-categorization.md). The
sync wave `-2` runs before the data layer's sync wave `-1`, so the
operator is up before the Cluster CR is registered. This element is
unchanged by the CloudNativePG pivot; only its `version` field moves as
upstream releases.

The `Cluster` CR lives at
[`apps/cloudnative-pg/clusters/postgresql.yaml`](../../apps/cloudnative-pg/clusters/postgresql.yaml)
under `apiVersion: postgresql.cnpg.io/v1`, `kind: Cluster`. It is deployed
via the standalone ArgoCD `Application` at
[`apps/cloudnative-pg/clusters/application.yaml`](../../apps/cloudnative-pg/clusters/application.yaml).
The wrapper-chart pattern from the planner pass is explicitly rejected
in [ADR-0009](../adr/0009-cloudnative-pg-for-platform-data-layer.md)
§Decision — a single `Cluster` CR is plain YAML, and a Helm wrapper
adds chart-versioning and two-file synchronization overhead that does not
pay back for one resource. The `version: 0.1.0` pin in
§Architecture / Contract above is **reserved** for a future wrapper chart
(if the platform ever grows to multi-Cluster manifests per cluster); the
current standalone-Application path carries no wrapper-chart semver. The
CR's `spec.postgresqlVersion: "17"` pins the major version the operator
pulls at apply time.

The per-environment contract file at
[`apps/values/dev/postgresql.yaml`](../../apps/values/dev/postgresql.yaml)
records the per-environment overrides as documentation (human-readable
shape, not consumed by ArgoCD — the ArgoCD-rendered `Cluster` CR is the
source of truth at apply time). The file documents the eventual
`bootstrap.initdb.secret.name: postgresql-credentials` reference that
hooks into the Sealed Secrets controller (Track C, per
[ADR-0008](../adr/0008-sealed-secrets-for-dev-and-stage.md)). The
per-environment file does not carry chart-version pins — those live in
the ApplicationSet element.

## Implementation / Procedure

The upgrade playbook. Run on every operator-chart or `postgresqlVersion`
bump. No step is optional; the offline validation chain in step 4 catches
structural errors before the change reaches the cluster, and the cluster
probe in step 6 catches the runtime equivalent before the change is
considered merged.

1. **Decide the new pin.** Read the upstream
   [`Chart.yaml`](https://raw.githubusercontent.com/cloudnative-pg/charts/main/charts/cloudnative-pg/Chart.yaml)
   for the operator chart and the
   [CloudNativePG release notes](https://github.com/cloudnative-pg/cloudnative-pg/releases)
   for the operator `appVersion` + PostgreSQL major-version support window.
   Pick one minor bump at a time.
2. **Edit `apps/dev/appset.yaml`.** On the `cloudnative-pg` element, set
   `version: <new operator chart version>`. Example: `version: 0.30.0`.
   The `version` field on the element is what the ApplicationSet template
   interpolates into the generated Application's `targetRevision` via
   `{{ .version }}`. If the new operator version changes the controller
   image in a way that affects the rendered Cluster shape (new `spec`
   fields, deprecated fields), step 3 applies; otherwise skip step 3.
3. **Edit `apps/cloudnative-pg/clusters/postgresql.yaml` only if needed.**
   The Cluster CR body lands at this path on disk; ArgoCD reconciles it
   as a plain manifest via the standalone Application. Edit only when the
   new operator version changes the rendered Cluster shape (new `spec`
   fields the platform wants to set, deprecated fields the platform
   wants to drop, or a baseline knob the platform wants to change). For a
   pure upstream chart-bump that does not change the rendered shape, no
   edit to this file is required.
4. **Run offline validation.** Both commands must exit `0` before the
   commit lands.

   ```bash
   helm lint apps/appprojects/
   helm template postgresql https://cloudnative-pg.github.io/charts --version <new> \
     > /tmp/cnpg-rendered.yaml
   kubeconform -strict -summary -ignore-missing-schemas /tmp/cnpg-rendered.yaml
   ```

   The first command validates the AppProject chart (the operator install's
   source-allowlist is unchanged, but `helm lint` is cheap and catches the
   accidental-regression case). The second validates the operator chart's
   rendered output against the upstream CRD schema. The
   `-ignore-missing-schemas` flag is required because the
   `postgresql.cnpg.io/v1` Cluster CRD is not bundled with kubeconform's
   default schemas; the flag suppresses missing-schema warnings for the
   Cluster kind while still validating everything else. ArgoCD-side
   admission control enforces the actual CRD validation at sync time.
5. **Push; ArgoCD auto-syncs to `dev`.** No manual `kubectl apply`. The
   ApplicationSet diff propagates to the per-component Application
   `cloudnative-pg-dev` (operator install). If the new operator version
   changes the rendered Cluster shape, push the Cluster CR change in the
   same window so ArgoCD reconciles the `Cluster` against the new
   operator.
6. **Verify on cluster.** Both probes, both must pass.

   ```bash
   kubectl get application -n argocd cloudnative-pg-dev
   kubectl get pods -n cloudnative-pg-dev -l cnpg.io/cluster=postgresql-dev \
     -o jsonpath='{.items[*].spec.containers[0].image}'
   ```

   The first probe's expected output is `Synced/Healthy` within the ArgoCD
   reconcile window. The second probe's expected output begins with
   `ghcr.io/cloudnative-pg/postgresql:17-<tag>` — the operator's image is
   determined by `postgresqlVersion` + operator version. If a `postgresqlVersion`
   bump (e.g., `17` → `18`) was part of the change, the image tag's major
   number must reflect the new pin.

For a `postgresqlVersion` major bump, an additional RFC + §Acceptance
note is required before step 1; the playbook above handles minor operator
chart bumps but not a major-Postgres upgrade. The major-bump procedure
is left to the RFC at upgrade time.

## Verification

The end state of a successful bump is testable from the cluster API and
the ArgoCD CLI. Both probes in §Implementation / §Procedure step 6 must
return the expected output. The first confirms the ArgoCD-side
reconciliation; the second confirms the operator pulled the pinned
PostgreSQL container image and not a cached or default-resolved variant.

This spec's Status is `Draft` at commit time. After Workstream A
(ApplicationSet, Cluster CR, per-environment file) lands together and the
on-cluster verify chain passes on at least one ArgoCD reconcile — that
is, on at least one real cluster having walked through §Implementation /
§Procedure steps 1–6 and observed both probes green — the follow-up PR
flips the Status blockquote to `Implemented`. Until that has happened on
at least one cluster, the Status stays `Draft`. This is the same
Pattern X gate.

## References

- [ADR-0001 — AppProjects generated from a Helm chart with committed `rendered/` manifests](../adr/0001-appprojects-helm-rendered.md)
- [ADR-0003 — Three-tier workload categorization](../adr/0003-three-tier-categorization.md) — places PostgreSQL in the `platform` AppProject and the operator install in `infrastructure`
- [ADR-0007 — Bitnami PostgreSQL chart for the platform foundation](../adr/0007-bitnami-postgresql-chart-for-platform-foundation.md) — superseded; the Bitnami-chart rationale that preceded ADR-0009
- [ADR-0008 — Sealed Secrets for `dev` and `stage`; defer ESO to `prod` via RFC-0004](../adr/0008-sealed-secrets-for-dev-and-stage.md) — the `bootstrap.initdb.secret.name: postgresql-credentials` seam
- [ADR-0009 — CloudNativePG for the platform data layer](../adr/0009-cloudnative-pg-for-platform-data-layer.md) — the architectural decision this spec implements
- [RFC-0005 — Initial workload rollout sequence](../rfc/0005-initial-workload-rollout-sequence.md) — Phase 0 rewritten for the Cluster CR pattern
- [SPEC-0003 — Adding a new component](../specs/0003-adding-a-new-component.md) — the registration contract; the generator-element `version` field is the operator-chart pin
- [`apps/cloudnative-pg/clusters/postgresql.yaml`](../../apps/cloudnative-pg/clusters/postgresql.yaml) — the `Cluster` CR with `spec.postgresqlVersion: "17"`
- [`apps/cloudnative-pg/clusters/application.yaml`](../../apps/cloudnative-pg/clusters/application.yaml) — the standalone ArgoCD `Application` that reconciles the `Cluster` CR
- [`docs/adding-a-new-application.md`](../adding-a-new-application.md) — §Example A is the CloudNativePG worked example
- `https://cloudnative-pg.io` — project site
- `https://github.com/cloudnative-pg/charts` — operator chart source (CHANGELOG, `Chart.yaml`)
- `https://github.com/cloudnative-pg/cloudnative-pg` — operator source; release notes for `appVersion` and PostgreSQL support window

## Title

Adopt Sealed Secrets for `dev` and `stage`; defer External Secrets Operator (ESO) + Vault / AWS Secrets Manager to `prod` via RFC-0004.

> **Status:** Accepted
>
> **Date:** 2026-07-08

## Context

The `platform` AppProject explicitly permits `kind: Secret` in its
namespace-resource whitelist
([`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml):80),
which is intentional — the data layer (PostgreSQL, Redis, Kafka) needs
credentials. The current pattern in
[`docs/adding-a-new-application.md`](../adding-a-new-application.md) §Example A
commits plaintext passwords (`admin-dev`, `lake-dev`) to Git history. Track A
of this plan ([SPEC-0006](../specs/0006-cloudnative-pg-pinning-and-cluster-cr-contract.md))
layers chart and image-tag version pinning on top, but the pinned values still
leak credentials to Git history unless a separate mechanism handles them. The
decision must take a position on [RFC-0002](../rfc/0002-secrets-management.md)
§Open Questions (Single cluster or multi-cluster target? Which cloud?);
[RFC-0002](../rfc/0002-secrets-management.md) §Recommended path proposes
"Sealed Secrets for `dev` and `stage`; ESO + Vault or AWS Secrets Manager for
`prod`." This ADR ratifies that recommendation as the binding decision.

Airflow 3 ([RFC-0005](../rfc/0005-initial-workload-rollout-sequence.md)
§Phase 2) inherits this strategy because its metadata-DB connection string is
a real credential and any `apps/values/{env}/airflow.yaml` written against the
current §Example A shape would repeat the leak.

## Decision

We adopt Bitnami Sealed Secrets for `dev` and `stage` as the first secrets
operator. ESO + Vault / AWS Secrets Manager for `prod` is deferred until
[RFC-0004](../rfc/0004-multi-cluster-progression.md) multi-cluster topology
and platform-cloud decisions resolve. The controller install is a separate
follow-up commit (Track C); this ADR authorizes the choice, it does not
install the operator today. Workloads that consume PostgreSQL credentials
(Trino, Nessie, Airflow, Metabase, Superset, JupyterHub) reference the
operator-rendered `Secret` by name via `auth.existingSecret` (or the
chart-equivalent seam). The `apps/values/dev/postgresql.yaml` shape defined
in [SPEC-0006](../specs/0006-cloudnative-pg-pinning-and-cluster-cr-contract.md)
§Implementation already carries the `auth.existingSecret: ""` seam; once the
controller is installed and a SealedSecret is committed, the only edit needed
is to set `auth.existingSecret: postgresql-credentials` and to populate the
SealedSecret YAML in a sibling `apps/secrets/dev/postgresql/sealed-secret.yaml`.

## Consequences

- `apps/appprojects/values.yaml` must add `SealedSecret` to
  `namespaceResourceWhitelist` once the operator is installed (Track C,
  out of scope).
- `docs/adding-a-new-application.md` §Example A values file uses
  `auth.existingSecret` and `auth.secretKeys`; the literal `password` /
  `postgresPassword` fields are removed.
- Workloads that consume PostgreSQL credentials (Phase 1+ per
  [RFC-0005](../rfc/0005-initial-workload-rollout-sequence.md)) reference
  `existingSecret` instead of literal strings.
- Airflow 3's metadata-DB connection string
  ([RFC-0005](../rfc/0005-initial-workload-rollout-sequence.md) §Phase 2)
  inherits the same sealed-secret pattern.
- `prod` will diverge. If AWS becomes the prod target per
  [RFC-0004](../rfc/0004-multi-cluster-progression.md), AWS Secrets Manager
  is the likely backend and Sealed Secrets may be retired for `prod`
  workloads. This ADR does not foreclose that path.

## Alternatives Considered

- **ESO-only (deferred for `prod` per the recommended split).**
  Production-grade rotation ergonomics and audit trail, but the backend
  (Vault or AWS Secrets Manager) is not yet picked and the operational lift
  is not warranted for `dev` and `stage`.
- **Vault-direct (rejected per
  [RFC-0002](../rfc/0002-secrets-management.md) §Alternatives Considered).**
  Pushes auth logic into every workload chart and breaks the values-file
  ergonomics.
- **SOPS-encrypted values files (rejected per
  [RFC-0002](../rfc/0002-secrets-management.md) §Alternatives Considered).**
  The decryption key lives on the operator's workstation; rotation is a code
  change; cluster never sees the plaintext directly.
- **Bitnami Sealed Secrets `controller2` instead of `controller`.**
  Deferred to Track C install time; switch if the existing `controller` image
  is end-of-life.

## References

- [ADR-0003 — Three-tier workload categorization](../adr/0003-three-tier-categorization.md) — places the data layer in `platform`
- [ADR-0009](../adr/0009-cloudnative-pg-for-platform-data-layer.md) — the data-layer workload that introduces the credentials (CloudNativePG operator + Cluster CR pattern)
- [ADR-0007](../adr/0007-bitnami-postgresql-chart-for-platform-foundation.md) — superseded by ADR-0009; retains the Bitnami-chart rationale for historical record
- [RFC-0002 — Secrets management strategy](../rfc/0002-secrets-management.md) — the proposal this ADR ratifies
- [RFC-0004 — Multi-cluster progression](../rfc/0004-multi-cluster-progression.md) — gates the `prod` backend choice
- [RFC-0005 — Initial workload rollout sequence](../rfc/0005-initial-workload-rollout-sequence.md) — Airflow 3 §Phase 2 inherits the pattern
- [SPEC-0003 — Adding a new component](../specs/0003-adding-a-new-component.md) — the registration contract; the values-file shape evolves under it
- [`docs/adding-a-new-application.md`](../adding-a-new-application.md) — §Example A is rewritten under TB4

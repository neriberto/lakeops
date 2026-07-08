## Title

Secrets management strategy (Sealed Secrets vs External Secrets Operator)

> **Status:** Accepted
>
> **Date:** 2026-07-07
>
> **Author(s):** lakeops maintainers

## Motivation

The `platform` AppProject explicitly permits `kind: Secret` in its
namespace-resource whitelist
([`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml):80),
which is correct — the data layer (PostgreSQL, Redis, Kafka) needs
credentials. The dev walkthrough in
[`docs/adding-a-new-application.md`](../adding-a-new-application.md):104-105
demonstrates the current pattern: hard-coded passwords in a values file.

```yaml
# apps/values/dev/postgresql.yaml
auth:
  database: lake
  username: lake
  password: lake-dev          # committed in plaintext
  postgresPassword: admin-dev # committed in plaintext
```

This works for local development but is not viable for stage or prod. Plain
`Secret` resources are base64-encoded in the Git history forever; rotating a
password requires a code change; there is no audit trail. The repository
needs a secrets strategy before stage or prod can carry real credentials.

## Proposal

Evaluate two candidates against the criteria below and pick one (or a
combination) for `lakeops`.

**Candidate A — Bitnami Sealed Secrets.** A controller running in the
cluster encrypts each `Secret` with a cluster-scoped key pair; the
encrypted `SealedSecret` CRD is safe to commit to Git. The controller
decrypts on the fly into a regular `Secret` resource. The encryption key
is per-cluster, so a sealed secret committed to the public `lakeops`
repository cannot be decrypted against any other cluster.

**Candidate B — External Secrets Operator (ESO) with Vault or AWS Secrets
Manager.** ESO watches `ExternalSecret` CRDs in the cluster and reconciles
them against a remote backend (HashiCorp Vault, AWS Secrets Manager,
GCP Secret Manager, Azure Key Vault). The Git repository holds only the
*reference* (path, key) — never the value. Rotation is a property of the
backend; the cluster fetches the new value automatically.

### Decision criteria

| Criterion                              | Sealed Secrets       | ESO + backend                |
| -------------------------------------- | -------------------- | ---------------------------- |
| Cluster lock-in                        | Per-cluster key      | Backend-issued credentials   |
| Operator lifecycle under ArgoCD        | Helm-managed         | Helm-managed                 |
| Rotation ergonomics                    | Re-encrypt + commit  | Backend-driven, no commit    |
| Public repository safety               | Safe (per-cluster)   | Safe (no values committed)   |
| Runtime dependency                     | Cluster only         | Cluster + backend reachable  |
| Operational complexity                 | Low                  | Medium (backend to operate)  |
| Cost                                   | Free                 | Backend cost (Vault / AWS)   |
| Multi-cluster (see [RFC-0004](0004-multi-cluster-progression.md)) | Per-cluster encryption | Shared or per-cluster backend |

**Recommended path.** Start with Sealed Secrets for dev and stage to remove
plaintext from Git with minimum operational lift; migrate to ESO + Vault (or
AWS Secrets Manager, if prod lands on AWS first) for prod. Both can coexist
in the same cluster during the migration; the operator CRDs do not collide.

## Drawbacks

- **Sealed Secrets:** a leaked cluster private key compromises every sealed
  secret for that cluster. Key rotation requires re-encrypting every
  secret. The cluster-scoped key is a single point of failure that must be
  backed up.
- **ESO:** every secret has a runtime dependency on the backend being
  reachable. A backend outage pauses reconciliation; pods that mount the
  secret may fail to start. Vault HA or AWS Secrets Manager mitigates this
  but adds cost.
- **Both:** the `platform` AppProject must continue to allow `kind: Secret`
  (the runtime artifact); the new CRDs (`SealedSecret`, `ExternalSecret`)
  must be added to the namespace-resource whitelist. The
  [`values.yaml`](../../apps/appprojects/values.yaml):56-108 whitelist
  becomes longer with each new CRD.
- **Both:** chart values that previously hard-coded a password now have to
  reference the secret by name. Every dev walkthrough example needs
  updating.

## Alternatives Considered

- **Plain `kind: Secret` with `stringData` for everything.** Already the
  status quo; rejected because secrets end up in Git history unencrypted
  and rotation is a code change.
- **HashiCorp Vault-only (no ESO).** Possible — pods can authenticate to
  Vault directly via the Kubernetes auth method — but pushes auth logic
  into every workload chart and breaks the values-file ergonomics.
- **SOPS-encrypted values files.** Encrypts the values YAML before commit;
  `helm-secrets` decrypts at apply time. Works without a cluster operator
  but the decryption key lives on the operator's workstation, and the
  cluster never sees the plaintext directly. Limited rotation ergonomics;
  every change is a re-encrypt.

## Open Questions

- **Single cluster or multi-cluster target?** Sealed Secrets encryption
  keys are per-cluster; if stage and prod share a single sealed secrets
  controller they share a key. Cross-cluster secrets will require ESO or a
  per-cluster key strategy. See [RFC-0004](0004-multi-cluster-progression.md).
- **Cloud target?** If prod lands on AWS, AWS Secrets Manager is the
  obvious backend and ESO is the obvious operator. If prod stays on bare
  metal microk8s, Vault is the closer fit and ESO is the operator. The
  choice can be deferred until the prod target is decided.
- **Public vs private repository?** Sealed Secrets are safe in a public
  repo because the encryption key is per-cluster. ESO + Vault with no
  values in Git is also safe in a public repo. The current `lakeops`
  repository is public; both candidates respect that constraint.

## References

- [ADR-0003 — Three-tier workload categorization](../adr/0003-three-tier-categorization.md)
- [RFC-0004 — Multi-cluster ArgoCD topology](0004-multi-cluster-progression.md)
- [`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml):80
- [`docs/adding-a-new-application.md`](../adding-a-new-application.md):104-105
- [ADR-0008](../adr/0008-sealed-secrets-for-dev-and-stage.md) — ratifies this RFC; Sealed Secrets for `dev` and `stage`, ESO + Vault / AWS Secrets Manager deferred to `prod` per RFC-0004

## Acceptance note

Accepted **2026-07-08** per [ADR-0008](../adr/0008-sealed-secrets-for-dev-and-stage.md) — Sealed Secrets for `dev` and `stage`; External Secrets Operator (ESO) + Vault / AWS Secrets Manager deferred to `prod` per [RFC-0004](0004-multi-cluster-progression.md).

The §Open Questions on cluster topology ("Single cluster or multi-cluster target?") and cloud target ("Cloud target?") are deliberately left open by this acceptance. ADR-0008 records the decision without resolving them — RFC-0004 retains ownership of those axes. Track A of the broader 2026-07-08 plan implements the CloudNativePG pivot via [SPEC-0006](../specs/0006-cloudnative-pg-pinning-and-cluster-cr-contract.md); Track C (separate future workstream) installs the Sealed Secrets controller.
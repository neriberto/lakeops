## Title

`dev` → `stage` → `prod` promotion pipeline

> **Status:** Proposed
>
> **Date:** 2026-07-07
>
> **Author(s):** lakeops maintainers

## Motivation

Today, dev, stage, and prod all target the same microk8s cluster (see
[`README.md`](../../README.md):118-126). The environments are nominally
separate namespaces and separate value files
(`apps/values/{dev,stage,prod}/{component}.yaml`) but the cluster boundary
is not enforced. Promoting a change from dev to prod is a manual copy of
the values file from `apps/values/dev/` to `apps/values/stage/` and
`apps/values/prod/`, followed by a commit. There is no record of what was
promoted when, no gate between environments, and no notion of a "release".

This works while all three environments share a cluster. Once stage and
prod move to dedicated clusters (see
[RFC-0004](0004-multi-cluster-progression.md)), the manual copy becomes a
cross-cluster promotion with no automation, no audit, and no rollback path.

## Proposal

Introduce a promotion gate that moves a tagged release between
ApplicationSets without duplicating value files.

### Components

1. **Tag-based release.** Each promotion begins by tagging the Git
   repository (`git tag -a v0.4.0 <sha>`). The tag is the canonical
   identifier of "what is being promoted."

2. **Per-environment `targetRevision`.** Each ApplicationSet's `sources[*]`
   currently set `targetRevision: main` (or a chart version). Move this to
   a per-environment override that points at the env-specific release tag.
   A simple implementation:

   ```yaml
   # apps/dev/appset.yaml  (template fragment)
   sources:
     - repoURL: https://github.com/neriberto/lakeops
       targetRevision: dev-latest   # mutable pointer, updated on promotion
       ref: values
   ```

   The pointer is updated by the promotion automation (or by a manual
   commit) when a release graduates to the next environment.

3. **Promotion automation.** Choose one of:

   - **GitHub Actions workflow.** A reusable workflow
     (`promote.yml`) that takes `{tag, from_env, to_env}` and opens a PR
     that bumps `targetRevision` for the destination env. Code review on
     the PR is the audit trail; merging is the gate.
   - **Kargo.** A promotion controller that watches ApplicationSets and
     advances them through stages with explicit promotion criteria
     (health checks, manual approval). Operates as a sibling to ArgoCD.
   - **Argo Rollouts controller.** Originally for progressive delivery
     of Deployments; the rollouts-controller has expanded to cover
     ApplicationSet promotion patterns. Heavier dependency than Kargo.

4. **Env-specific overrides stay env-local.** Storage sizes, replica
   counts, and other resource sizes remain in
   `apps/values/{env}/{component}.yaml`. The promotion moves the
   *chart values reference* and the *chart version*, not the resource
   sizes.

### Initial recommendation

Start with the GitHub Actions workflow for the first promotion because it
has no new dependencies and reuses the existing PR-review process as the
gate. Migrate to Kargo once the team is comfortable with the promotion
semantics and wants automation between manual stages.

## Drawbacks

- **Tag churn.** A tag per promotion inflates the Git tag list. A cleanup
  policy that retains the last N tags per environment mitigates this.
- **Merge conflicts.** Bumping `targetRevision` in three places (one per
  env) creates the same merge conflict pattern as version bumps in any
  multi-file config. Mitigated by isolating `targetRevision` to a single
  field per env.
- **Promotion automation dependency.** Kargo and the rollouts controller
  introduce new cluster operators that need their own AppProject, RBAC,
  and bootstrap ordering. Each is a meaningful operational addition.
- **Snapshot scope.** A promotion that snapshots the full Application
  state (chart values + values files + AppProject allowlists) is more
  auditable than a promotion that only moves `targetRevision`. Snapshotting
  is heavier; the initial implementation snapshots only `targetRevision`.

## Alternatives Considered

- **One ApplicationSet per environment with independent values files (status
  quo).** Manual copy, no audit trail, no rollback. Works at the cost of
  every promotion being a manual commit; rejected because it does not
  scale beyond a single human operator.
- **GitOps promotion via ArgoCD AppSets-of-Appsets.** ArgoCD can chain
  Applications across environments using sync waves, but the chain runs in
  one cluster; cross-cluster promotion requires either Kargo or a
  cross-cluster ApplicationSet topology (see
  [RFC-0004](0004-multi-cluster-progression.md)).
- **Branch-based promotion (`dev`, `stage`, `prod` as branches).** Each
  promotion is a merge. Rejected because branches as environments
  duplicate state and make the env-specific values files harder to reason
  about than path-based environments.

## Open Questions

- **Kargo vs rollouts-controller vs bespoke GitHub Actions?** Each has a
  different operational footprint. Kargo is the most natural fit for
  ApplicationSet promotion; the rollouts controller is more general but
  heavier; a GitHub Actions workflow is the lightest starting point. See
  the initial recommendation in the Proposal.
- **Snapshot full Application state or only `targetRevision`?** A full
  snapshot is more auditable but heavier; a `targetRevision`-only snapshot
  is lighter but loses the diff between the snapshot and the current
  commit. The choice depends on what the team wants to review on a
  promotion PR.
- **Divergence handling for env-specific overrides?** Storage sizes in
  `apps/values/prod/seaweedfs.yaml` will legitimately differ from
  `apps/values/dev/seaweedfs.yaml`. The promotion should not touch these
  files; the gate only moves the env pointer. Confirming this contract
  with the team is part of the proposal's rollout.

## References

- [ADR-0005 — Per-environment ApplicationSets](../adr/0005-per-environment-applicationsets.md)
- [RFC-0004 — Multi-cluster ArgoCD topology](0004-multi-cluster-progression.md)
- [`README.md`](../../README.md):118-126
- [`apps/dev/appset.yaml`](../../apps/dev/appset.yaml)
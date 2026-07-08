## Title

AppProjects generated from a Helm chart with committed `rendered/` manifests

> **Status:** Accepted
>
> **Date:** 2026-07-07

## Context

ArgoCD AppProjects define the security boundary for every Application deployed
in the cluster: which Helm repositories are trusted, which destinations
(clusters and namespaces) are reachable, and which Kubernetes resource kinds
each project is allowed to create. The `lakeops` platform needs three
AppProjects — `infrastructure`, `platform`, `workloads` — that differ only in
name and description. Everything else (`sourceRepos`, `destinations`,
`clusterResourceWhitelist`, `namespaceResourceWhitelist`, `orphanedResources`)
must be identical so that drift between categories is impossible by
construction.

Managing these by hand invites drift: a typo in `destinations` for one
project, a missing `kind: Secret` for another. ArgoCD itself has no mechanism
to keep AppProject definitions in lockstep — each is an independent CRD
instance. We need a single source of truth and a way to apply the result
without requiring ArgoCD to run Helm at sync time.

## Decision

AppProjects are rendered from a small Helm chart whose single source of truth
is [`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml). The
chart template at
[`apps/appprojects/templates/appproject.yaml`](../../apps/appprojects/templates/appproject.yaml)
iterates over `.Values.projects` and emits one `AppProject` per entry; all
other fields (sourceRepos, destinations, whitelists) are uniform across the
three categories by virtue of being shared values.

The render script
[`scripts/render-appprojects.sh`](../../scripts/render-appprojects.sh) runs
`helm template apps/appprojects/ -s templates/appproject.yaml` and `csplit`s
the output at `---` boundaries into three files under
[`apps/appprojects/rendered/`](../../apps/appprojects/rendered/), named after
the AppProject (00 → infrastructure, 01 → platform, 02 → workloads). The
`rendered/` tree is **committed** to the repository so ArgoCD can apply the
plain YAML directly — no Helm-aware pipeline runs at sync time.

CI (see [ADR-0006](0006-rendered-drift-ci-precommit.md)) and the local
pre-commit hook re-run the script and diff against the committed files, so a
change to `values.yaml` without a re-render fails the check.

## Consequences

- Adding a fourth AppProject means appending one entry to `.Values.projects`
  and re-running the render script. The allowlist and destination blocks are
  inherited automatically.
- Drift between AppProjects is structurally impossible because the only
  varying inputs are `name` and `description`.
- ArgoCD does not need Helm at apply time, keeping the bootstrap Application
  minimal and the failure modes obvious.
- Authors must remember to commit both `values.yaml` and the matching
  `rendered/*.yaml` files; the drift check and pre-commit hook are the
  enforcement.

## Alternatives Considered

- **Hand-written `AppProject` YAML files per category.** Simple, but every
  shared field becomes a copy-paste hazard. Any update to sourceRepos or
  destinations has to be made in three places and kept in lockstep manually.
- **ArgoCD `ApplicationSet` generating AppProjects.** AppProjects are CRDs
  that already exist in the cluster; generating them via an ApplicationSet
  introduces an unnecessary layer of indirection and makes the bootstrap
  dependency graph harder to reason about.
- **Kustomize instead of Helm.** Kustomize can produce three outputs from a
  base + overlay, but the values are flat key/value and lose the structure
  (per-project name + description) that Helm expresses naturally.

## References

- [ADR-0006 — CI drift-check + pre-commit hook](0006-rendered-drift-ci-precommit.md)
- [ADR-0003 — Three-tier workload categorization](0003-three-tier-categorization.md)
- [ADR-0004 — Defense-in-depth AppProject configuration](0004-defense-in-depth-appproject-config.md)
- [`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml)
- [`apps/appprojects/Chart.yaml`](../../apps/appprojects/Chart.yaml)
- [`apps/appprojects/templates/appproject.yaml`](../../apps/appprojects/templates/appproject.yaml)
- [`scripts/render-appprojects.sh`](../../scripts/render-appprojects.sh)
- [`apps/appprojects/rendered/`](../../apps/appprojects/rendered/)
## Title

CI drift-check + pre-commit hook to keep `rendered/` in sync with chart source

> **Status:** Accepted
>
> **Date:** 2026-07-07

## Context

The render pattern from [ADR-0001](0001-appprojects-helm-rendered.md) commits
two artifacts: the chart source (`apps/appprojects/values.yaml`, `Chart.yaml`,
`templates/`) and the rendered output (`apps/appprojects/rendered/*.yaml`).
ArgoCD applies the rendered output, not the chart. If the source changes
without a re-render, ArgoCD silently applies the stale manifest and the
allowlist drift goes unnoticed.

We need two enforcement layers: a local layer that catches the drift before
the commit lands, and a CI layer that catches the drift if the local layer
was bypassed (a contributor without `pre-commit install`, a force-push, a hotfix
applied through the GitHub web UI).

## Decision

**Pre-commit hook.** `.pre-commit-config.yaml` registers a local hook named
`render-appprojects` that runs `bash scripts/render-appprojects.sh` whenever
files matching `^apps/appprojects/(values\.yaml|Chart\.yaml|templates/.*)$`
change. The hook stages any changes to the rendered files into the same
commit so the commit and the re-render land together.

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: render-appprojects
      name: Render AppProject Helm chart
      entry: bash scripts/render-appprojects.sh
      language: system
      pass_filenames: false
      files: |
        ^apps/appprojects/(values\.yaml|Chart\.yaml|templates/.*)$
```

**CI drift-check.** The
[`drift-check`](../../.github/workflows/lint.yaml) job in
`.github/workflows/lint.yaml` runs on every push to `main` and every
pull request:

1. Checkout the repository.
2. Install Helm and `csplit` (via `coreutils`/`moreutils` apt packages).
3. Run `bash scripts/render-appprojects.sh` to regenerate
   `apps/appprojects/rendered/`.
4. Run `git diff --exit-code --stat apps/appprojects/rendered/`. If the diff
   is non-empty, the workflow fails with an `::error::` annotation pointing
   the contributor at the render command.

The companion job `lint-chart` runs `helm lint` and `helm template | kubeconform`
against the same chart for structural and schema validation. The drift check
is the safety net for the pre-commit hook; both layers are required because
either alone has a known bypass mode (no `pre-commit install` for the local
hook; race condition or non-`main` push for the CI hook).

### Known state

The drift check will fail on the next push after this ADR lands. The
committed `apps/appprojects/rendered/*.yaml` files contain a single
`destinations` entry, while the current `apps/appprojects/values.yaml`
declares three duplicate entries (one per environment — dev, stage, prod).
This drift is recorded here rather than silently fixed so that the
resolution — a separate code PR that cleans up the values block to a single
canonical entry — gets reviewed on its own merits.

## Consequences

- A change to `values.yaml` cannot land without the matching render. The
  pre-commit hook prevents the most common bypass; CI catches the rest.
- The CI job depends on `csplit` being installed in the runner image; the
  workflow installs `coreutils` and `moreutils` explicitly via `apt-get`.
- The render script's reliance on the suffix order
  (`00 → infrastructure, 01 → platform, 02 → workloads`) is fragile if the
  `.Values.projects` order changes. The script's `NAMES` map would have to
  be updated alongside; this is a known coupling that the drift check does
  not currently validate.
- The known drift in `destinations` will surface as a CI failure on the
  next push. Reviewers should expect that failure and route it to the code
  PR that resolves it.

## Alternatives Considered

- **Render at ArgoCD sync time** (no committed `rendered/`). Would require
  ArgoCD to run Helm at apply time and removes the simple "this is the YAML
  ArgoCD sees" property that makes the bootstrap Application minimal.
- **Render-only-in-CI** (no local hook). Pushes the render to a CI step
  that commits back to the PR branch; the PR-author experience is worse
  because the re-render is a separate commit and a push loop.
- **Hash-based drift detection** (compare a hash of the source against a
  hash stored in the rendered file). More robust to file ordering but adds
  a metadata field to the rendered YAML that has no purpose at runtime.

## References

- [ADR-0001 — AppProjects generated from a Helm chart](0001-appprojects-helm-rendered.md)
- [`scripts/render-appprojects.sh`](../../scripts/render-appprojects.sh)
- [`.github/workflows/lint.yaml`](../../.github/workflows/lint.yaml)
- [`.pre-commit-config.yaml`](../../.pre-commit-config.yaml)
- [`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml):35-44
- [`apps/appprojects/rendered/`](../../apps/appprojects/rendered/)
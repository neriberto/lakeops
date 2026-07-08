## Title

Destination allowlist uniformity across AppProjects

> **Status:** Proposed
>
> **Date:** 2026-07-07
>
> **Author(s):** lakeops maintainers

## Motivation

`.Values.destinations` in
[`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml):35-44 is
rendered into every AppProject verbatim by the template at
[`apps/appprojects/templates/appproject.yaml`](../../apps/appprojects/templates/appproject.yaml):21-22.
This is intentional: all three AppProject categories share an identical
destination allowlist by construction (see [ADR-0004](../adr/0004-defense-in-depth-appproject-config.md)).
The header comment at
[`values.yaml`](../../apps/appprojects/values.yaml):9-10 marks this invariant
explicitly with `RFC 0001 §D4.6` and explains that the allowlist is not
keyed per project.

The invariant is currently invisible to CI. A future contributor can add a
new AppProject-specific destinations block in the template, or split the
shared block, and the existing drift check (see
[ADR-0006](../adr/0006-rendered-drift-ci-precommit.md)) will not catch it —
the check only verifies that `rendered/` matches `values.yaml`, not that the
template renders the same destinations into every AppProject. We need to
codify the uniformity invariant as a CI check and clarify the data shape
for when stage and prod move to dedicated clusters (off the single in-cluster endpoint).

## Proposal

1. **Keep the shared top-level `.Values.destinations` block.** All three
   AppProjects continue to read from a single list. No per-project override
   path is introduced.

2. **Introduce `.Values.clusters` as a named map** for clarity, separately
   from `destinations`:

   ```yaml
clusters:
  local-dev:
    server: https://kubernetes.default.svc
    description: Local dev (single-node, any conformant Kubernetes distribution)
  stage:
    server: https://kubernetes.default.svc
    description: Stage (single-node, any conformant Kubernetes distribution)
  prod:
    server: https://kubernetes.default.svc
    description: Prod (single-node, any conformant Kubernetes distribution)

   destinations:
     - server: "{{ .Values.clusters.local-dev.server }}"
       namespace: '*'
     - server: "{{ .Values.clusters.stage.server }}"
       namespace: '*'
     - server: "{{ .Values.clusters.prod.server }}"
       namespace: '*'
   ```

   The map gives every cluster a stable handle (`local-dev`, `stage`,
   `prod`) so future code (e.g., a per-env generator in an ApplicationSet)
   can reference clusters by name without re-typing the server URL. The
   `destinations` block remains the source of truth for ArgoCD.

3. **Add a CI guard for destination uniformity.** The
   [`lint.yaml`](../../.github/workflows/lint.yaml) `drift-check` job (or a
   new sibling job) parses every file in
   `apps/appprojects/rendered/` and asserts that the `spec.destinations`
   list is byte-identical across all three AppProjects. A divergence fails
   the workflow with a message naming the AppProject and the differing
   entries.

4. **Document the invariant** at the top of `.Values.destinations` with a
   reference to this RFC and a short rationale, replacing the existing
   inline comment so the link survives future refactors.

## Drawbacks

- The `clusters` map adds a layer of indirection. Contributors who only edit
  a server URL have to remember which handle to update.
- The uniformity CI guard duplicates information that is already enforced
  structurally by the template. If a contributor bypasses the template
  (writes a fourth AppProject by hand), the structural enforcement is
  already gone, so the guard adds real value only when the structure is
  regressed.
- The current shape has three duplicate `(server, namespace: '*')` entries
  because dev, stage, and prod all happen to point at the same in-cluster
  endpoint. Consolidating to a single entry is tempting but loses the
  per-env handles. This RFC keeps the duplication explicit for now and
  defers the consolidation decision to when the cluster URLs actually
  diverge.

## Alternatives Considered

- **Drop `destinations` to a single entry.** With all three envs on the
  same cluster, one entry is sufficient. Rejected because the moment a
  cluster diverges the work to add a second entry is non-trivial and easy
  to forget; keeping the entries explicit makes the migration a value
  change rather than a structural change.
- **Per-project destinations override.** Each `.Values.projects[i]` entry
  carries its own destinations block. Rejected because it reintroduces the
  drift problem [ADR-0001](../adr/0001-appprojects-helm-rendered.md) was
  designed to eliminate; categories share the same allowlist precisely so
  that no project can deploy to a destination another cannot.
- **OPA policy at the ArgoCD control plane.** More powerful but moves the
  invariant out of the manifests; the rendered YAML would no longer be
  self-describing.

## Open Questions

- **Flat shape vs cluster-keyed shape.** Should `.Values.clusters` be a
  flat map (`local-dev`, `stage`, `prod` as top-level keys) or nested
  under a `.clusters.<name>.server` shape with namespace defaults? The
  flat shape is shorter but loses a per-cluster namespace default if one
  is ever needed.
- **Absorbed by RFC-0004 or standalone?** Multi-cluster topology
  ([RFC-0004](0004-multi-cluster-progression.md)) will require per-cluster
  destinations in earnest. Should this RFC be folded into RFC-0004 and
  implemented as one change, or kept separate so the uniformity guard can
  land first and de-risk the bigger migration?

## References

- [ADR-0001 — AppProjects generated from a Helm chart](../adr/0001-appprojects-helm-rendered.md)
- [ADR-0004 — Defense-in-depth AppProject configuration](../adr/0004-defense-in-depth-appproject-config.md)
- [ADR-0006 — CI drift-check + pre-commit hook](../adr/0006-rendered-drift-ci-precommit.md)
- [RFC-0004 — Multi-cluster ArgoCD topology](0004-multi-cluster-progression.md)
- [`apps/appprojects/values.yaml`](../../apps/appprojects/values.yaml):35-44
- [`apps/appprojects/templates/appproject.yaml`](../../apps/appprojects/templates/appproject.yaml):21-22
- [`.github/workflows/lint.yaml`](../../.github/workflows/lint.yaml)
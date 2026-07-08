## Title

App-of-apps bootstrap with explicit sync waves (`-10` / `0`)

> **Status:** Accepted
>
> **Date:** 2026-07-07

## Context

ArgoCD's app-of-apps pattern lets a parent `Application` deploy the child
`Application` (and `ApplicationSet`) resources that actually do the work. For
`lakeops`, two bootstrap layers are needed before any workload can deploy:

1. **AppProject trio** (`infrastructure`, `platform`, `workloads`) — the RBAC
   and destination allowlists every subsequent Application inherits from.
2. **Per-environment ApplicationSets** — the generators that emit
   `Application` resources for individual components.

If these layers apply in the wrong order, ArgoCD will refuse to create the
child Applications: a workload `Application` that targets the `platform`
AppProject cannot exist before the `platform` AppProject itself exists, and
ArgoCD will surface "app project does not exist" errors. The bootstrap order
must be deterministic.

## Decision

The bootstrap uses two ArgoCD `Application` resources under
[`apps/bootstrap/`](../../apps/bootstrap/), each annotated with an explicit
ArgoCD sync wave so the order is enforced by ArgoCD rather than by the
`kubectl apply` invocation order.

```text
sync-wave -10  →  bootstrap-appprojects   (creates the AppProject trio)
sync-wave  0   →  bootstrap-{dev,stage,prod}
                                     (creates per-env ApplicationSets)
```

[`apps/bootstrap/appprojects.yaml`](../../apps/bootstrap/appprojects.yaml)
sets `argocd.argoproj.io/sync-wave: "-10"`. It sources the directory
`apps/appprojects/rendered` (with `include: '{infrastructure,platform,workloads}.yaml'`)
and reconciles the three rendered AppProject manifests directly.

[`apps/bootstrap/dev.yaml`](../../apps/bootstrap/dev.yaml) (and the stage and
prod siblings) set `argocd.argoproj.io/sync-wave: "0"` and source `apps/dev/`
which contains the `appset-dev` ApplicationSet. Once `appset-dev` exists, the
generator emits the per-component `Application` resources.

The negative wave for the AppProject Application is the convention ArgoCD
uses to mean "apply before everything else"; wave `0` is the default for
ordinary Applications. Component-level `Application`s defined inside the
ApplicationSet carry their own `syncWave` (negative for storage, positive for
workloads) to express intra-environment ordering.

## Consequences

- Bootstrap order is encoded in the YAML rather than in operator runbooks.
  Any contributor who `kubectl apply`s the bootstrap files in the wrong order
  still gets the right result because ArgoCD waits for the earlier wave.
- `bootstrap-appprojects` runs against the `default` ArgoCD AppProject. Until
  the three category AppProjects exist, there is no other choice; this is
  intentional and isolated to the bootstrap layer.
- The approach scales linearly: adding a fourth environment is one new file
  under `apps/bootstrap/` with the same wave-`0` annotation.
- A failed or stuck `bootstrap-appprojects` blocks everything downstream; the
  ArgoCD UI surfaces the wave ordering and the relevant failed resource.

## Alternatives Considered

- **Bootstrap script with `kubectl apply` in sequence.** Works locally but
  bypasses ArgoCD's reconciliation: if a user re-applies the bootstrap by
  accident, the order depends on the script. Encoding the order in sync
  waves makes it a property of the manifests, not the operator.
- **Single bootstrap `Application` that creates AppProjects and ApplicationSets
  in one shot.** ArgoCD's app-of-apps cannot apply two resource kinds that
  live in different paths with the same `Application`; splitting them keeps
  each `Application` focused on one source directory.
- **Manual `kubectl apply` per layer with a README instruction.** Fragile and
  undocumented in code; the sync-wave annotation is self-describing.

## References

- [ADR-0001 — AppProjects generated from a Helm chart](0001-appprojects-helm-rendered.md)
- [ADR-0005 — Per-environment ApplicationSets](0005-per-environment-applicationsets.md)
- [`apps/bootstrap/appprojects.yaml`](../../apps/bootstrap/appprojects.yaml)
- [`apps/bootstrap/dev.yaml`](../../apps/bootstrap/dev.yaml)
- [`docs/argocd.md`](../argocd.md)
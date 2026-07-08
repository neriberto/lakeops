# lakeops documentation

The `lakeops` repository is a GitOps control plane for a datalake and
lakehouse platform running on Kubernetes. ArgoCD reconciles the cluster
state against a versioned tree of `Application` and `ApplicationSet`
manifests, organized with the app-of-apps pattern. Every component —
storage, the shared data layer, and the datalake workloads — deploys
through the same pipeline: a values file, a generator element, and a
commit.

This documentation tree is the source of truth for design rationale and
implementation contracts. It complements the top-level `README.md`, which
remains the GitHub landing page.

## Operations guides

- [ArgoCD install and bootstrap](argocd.md) — installing ArgoCD on a
  cluster, fetching the admin password, port-forwarding the UI, and
  applying the bootstrap Applications in order.

## Tutorials

- [Adding a new application](adding-a-new-application.md) — the
  end-to-end workflow for registering a new Helm chart as a managed
  Application inside an environment. Includes worked examples for
  Bitnami PostgreSQL and Trino, the four generator-element fields
  (`chart`, `namespace`, `project`, `syncWave`), and a troubleshooting
  guide.

## Architecture Decision Records

- [ADR index](adr/README.md) — Architecture Decision Records (ADRs) capture
  significant technical decisions: the context that motivated them, the
  choice made, the trade-offs accepted, and the alternatives considered.
  ADRs are immutable once accepted. Superseding a decision means writing
  a new ADR that references the old one; the old record stays for
  historical context. Add an ADR whenever a change is non-trivial,
  long-lived, and constrains future design choices — for example, the
  decision to render AppProjects from a Helm chart, or the decision to
  use explicit `destinations` rather than `server: '*'`.

## Requests for Comments

- [RFC index](rfc/README.md) — Requests for Comments (RFCs) propose substantial
  changes before they are implemented: multi-cluster topology, secrets
  strategy, environment promotion, and similar architectural moves. An
  RFC is how the team surfaces motivation, weighs trade-offs, and
  resolves open questions before code lands. Accepted RFCs spawn a
  corresponding ADR that records the final decision. Add an RFC
  whenever a change crosses a system boundary, affects more than one
  team, or is reversible only with significant cost.

## Specifications

- [Spec index](specs/README.md) — Technical Specifications (Specs) describe
  concrete implementations in detail once an RFC is accepted and the
  decision is being executed: the shape of a Helm chart, the layout of
  a CI job, the wire format of an API, the contract between two
  scripts. Specs are living documents; they evolve alongside the code
  they describe. A spec's status is `Implemented` only when the code
  matches the specification; refinements are accepted as updates, not
  new specs. The relationship between the three document types is:
  **ADRs decide, RFCs propose, Specs implement.**

## Cross-references

The three documentation directories cross-link aggressively. ADRs cite the
RFCs and specs that informed them; specs cite the ADRs that authorize them;
RFCs cite the ADRs they propose to supersede. Use relative paths between
files so the tree remains a self-contained graph regardless of where the
repository is cloned.

## See also

- [Top-level `README.md`](../README.md) — repository overview,
  architecture diagram, environment model, and quickstart.

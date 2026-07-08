# Requests for Comments

This directory holds Requests for Comments (RFCs) for the `lakeops` GitOps
repository. An RFC proposes a substantial change before it is implemented:
multi-cluster topology, secrets strategy, environment promotion, and similar
architectural moves. RFCs are how we surface motivation, weigh trade-offs, and
resolve open questions with the team before code lands.

## Status legend

| Status    | Meaning                                                              |
| --------- | -------------------------------------------------------------------- |
| Proposed  | Open for discussion. Not yet implemented or approved.                |
| Accepted  | The team has agreed to proceed. An ADR or implementation PR should follow. |
| Rejected  | Considered and turned down. Kept for historical context.              |
| Withdrawn | The author withdrew the proposal. No decision was rendered.            |

## Index

1. [0001 — Destination allowlist uniformity across AppProjects](0001-destination-allowlist-uniformity.md)
2. [0002 — Secrets management strategy (Sealed Secrets vs External Secrets Operator)](0002-secrets-management.md)
3. [0003 — `dev` → `stage` → `prod` promotion pipeline](0003-env-promotion-path.md)
4. [0004 — Multi-cluster ArgoCD topology for `stage` and `prod`](0004-multi-cluster-progression.md)
5. [0005 — Initial workload rollout sequence](0005-initial-workload-rollout-sequence.md)

## Authoring a new RFC

Use filename pattern `NNNN-short-title.md` (zero-padded 4-digit ID, lowercase,
hyphen-separated). Use the RFC template — Title, Status, Date, Author(s),
Motivation, Proposal, Drawbacks, Alternatives Considered, Open Questions,
References — with relative paths for cross-references. Accepted RFCs should
spawn a corresponding ADR that records the final decision.
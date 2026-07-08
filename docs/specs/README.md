# Technical Specifications

This directory holds Technical Specifications (Specs) for the `lakeops` GitOps
repository. A spec describes a concrete implementation in detail — the shape
of a Helm chart, the layout of a CI job, the wire format of a webhook — once
the relevant RFC has been accepted and the decision is being executed. Specs
are living documents; they evolve alongside the code they describe.

## Status legend

| Status      | Meaning                                                              |
| ----------- | -------------------------------------------------------------------- |
| Draft       | Specification is being written or reviewed. Not yet reflected in code. |
| Implemented | The code matches the specification. Updates are accepted as refinements. |
| Superseded  | Replaced by a newer spec. The superseding spec is linked in References. |

## Index

No specs have been written yet. Specs will be added as accepted RFCs move into
implementation — for example, a spec for the multi-cluster topology described
in [RFC-0004](../rfc/0004-multi-cluster-progression.md) once the topology is
approved.

## Authoring a new spec

Use filename pattern `NNNN-short-title.md` (zero-padded 4-digit ID, lowercase,
hyphen-separated). Specs should be cross-referenced from the ADR or RFC they
implement and use relative paths for cross-references between docs files.
# 0002 — Docker image tagging strategy

## Status

Accepted

## Context

The CI pipeline builds a container image on every push and pull request.
The tag applied to that image is the handle used by every downstream
consumer: security scanners, deploy steps, rollback procedures, incident
triage. A tag that is ambiguous or mutable makes "which image is running
in production?" unanswerable.

Three common strategies were considered:

- **Immutable SHA only** (`git-<short-sha>`). Pure and traceable, but
  does not communicate role. A human cannot tell main from a feature
  branch without resolving the SHA.
- **Branch/PR only** (`main`, `pr-42`). Human-readable, but mutable —
  `main` points to a different image after every push.
- **Semantic version** (`v1.2.3`). Meaningful for release management,
  but this repo has no release process or downstream consumers to
  justify the ceremony.

## Decision

Apply **two tags to every image**:

- A branch or PR identifier (`main`, `pr-42`) — the human handle
- A commit-specific tag (`main-0f9ec57`, `pr-42-abc1234`) — the
  immutable handle

Both tags reference the same image content. The branch/PR tag answers
"what role does this image play?" The SHA-suffixed tag answers "which
exact commit produced this image?"

## Consequences

- Two questions, two tags. Consumers pick the one matching their need.
- `main` is mutable by design — it moves with every push to main. This
  is acceptable because the immutable handle is always available alongside
  it. Any workflow that requires a stable reference (Terraform, a deploy
  manifest) must use the SHA-suffixed tag, not the bare branch tag.
- The tag scheme maps naturally to path-filtered pipelines: `app-ci.yml`
  produces both tags on every build.
- If a registry is added later (GHCR, ACR), the same scheme applies
  unchanged.
  
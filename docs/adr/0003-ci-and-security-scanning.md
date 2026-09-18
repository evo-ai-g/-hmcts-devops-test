# 0003 — CI structure and security scanning

This ADR bundles three closely-related decisions made during Part 2.
They are recorded together because they share a common theme: how the
pipeline is structured and what it is allowed to block on.

## 3a — Split path-filtered pipelines instead of one monolithic workflow

### Context

The starter shipped a single `ci.yml` triggered on every push and PR.
The brief asks for build, test, Checkstyle, container image build,
Trivy scan, and Terraform checks. Putting all of that in one workflow
means a README-only change runs the Docker build and the vulnerability
scan, wasting CI minutes and producing noisy status checks.

### Decision

Two workflow files, each path-filtered:

- `app-ci.yml` — triggers on `src/**`, `build.gradle`, `Dockerfile`,
  `docker-compose.yml`, and related app paths.
- `infra-ci.yml` — triggers on `terraform/**` only.

The stale `ci.yml` was deleted rather than extended.

### Consequences

- A change to application code triggers only `app-ci.yml`. A Terraform
  change triggers only `infra-ci.yml`. A docs-only PR triggers neither.
- Path filters are the native GitHub Actions mechanism
  (`on.push.paths`). No third-party path-detection action is involved.
- Two files means the reader looks in two places. Accepted: each file
  is short and purpose-named.
- Adding a third pipeline surface (e.g. documentation linting) is a new
  file, not a modification of an existing one.

## 3b — Trivy: block on CRITICAL only, report HIGH, ignore unfixed

### Context

The brief mandates: block the pipeline on CRITICAL, warn on HIGH. Two
implementation details matter beyond the severity threshold itself.

First, Trivy's `exit-code` applies to any finding at or above the
`severity` setting. A single invocation with `severity: CRITICAL,HIGH`
and `exit-code: 1` would block on HIGH, contradicting the brief.

Second, Trivy by default reports vulnerabilities that have no fixed
version available in the base distribution's repositories. Blocking on
those leaves the developer with no action they can take to unblock the
pipeline — the only "fix" would be to switch the base image.

### Decision

Two Trivy invocations in sequence:

1. **Report pass** — `severity: CRITICAL,HIGH`, `ignore-unfixed: true`,
   `exit-code: 0`, SARIF output. Findings upload to the GitHub Security
   tab.
2. **Gate pass** — `severity: CRITICAL`, `ignore-unfixed: true`,
   `exit-code: 1`, table output. Fails the pipeline on CRITICAL only.

### Consequences

- The blocking gate only fires on vulnerabilities a developer can
  remediate by upgrading a package. Every failure is actionable.
- HIGH findings remain visible in the Security tab as SARIF without
  blocking merges.
- Unfixable vulnerabilities are invisible to this workflow by design.
  A scheduled non-blocking scan (weekly, unfiltered) would close this
  gap. Out of scope for this task; noted as a follow-up.
- Two invocations means Trivy runs twice per pipeline. Trivy is fast
  (seconds) and its database is cached by the action. Cost accepted in
  exchange for accurate severity semantics.

## 3c — No container registry push

### Context

The brief requires building the container image with a documented
tagging strategy. It does not require publishing to a registry.

### Decision

The pipeline builds the image on the runner, applies the two tags from
ADR 0002, and scans it. The image is not pushed anywhere.

### Consequences

- No registry credentials to manage. No secret to scope to this
  workflow.
- The tagging strategy is exercised (both tags are applied and used by
  Trivy), which is the part of the strategy the brief asks us to
  demonstrate.
- If a downstream consumer needs to pull the image (for a real
  deployment), the pipeline gains a `docker push` step and a login
  step. Two additions, not a redesign.
- The image is not retained past the workflow run. For a real pipeline,
  this would be a problem — images need to be pulled by deploy steps
  and re-scanned later. Accepted here because there is no deployment
  target yet.
  
# 0005 — GitHub free-tier constraints on security and governance features

## Status

Accepted — partially superseded. Code scanning became available when
the repository was made public. See the Update section below.

## Context

Three GitHub features that this repository's design depends on are
gated behind paid plans when the repository is private:

1. **Code scanning (CodeQL and SARIF uploads).** Required for the
   starter's `codeql.yml` and for uploading Trivy findings to the
   Security tab. Available on public repositories or with GitHub
   Advanced Security (a paid add-on).

2. **Rulesets.** The modern branch-protection interface. Available on
   public repositories or with GitHub Team/Enterprise for private
   repositories.

3. **Classic branch protection rules.** The older interface. Also
   gated on private repositories, requiring GitHub Team or higher.

The repository is private during the interview build. Flipping it to
public is planned before submission, but the intermediate state matters
for understanding what is and isn't enforced right now.

## Decision

Where a feature is gated, take the following approach:

- **Code scanning / CodeQL.** Remove `codeql.yml`. Trivy continues to
  scan the built image and gate on CRITICAL. SARIF upload is removed;
  findings print to the workflow log instead. Documented in ADR 0003.

- **Branch protection / rulesets.** Configure the rules. Leave them
  dormant until the repository is public or the org upgrades. Do not
  upgrade to a paid plan for a demo repository. Document the exact
  rules configured so they can be audited.

- **Dependabot alerts and security updates.** These are free on
  private repositories. Enable them.

## Consequences

- The repository's merge-gating design is complete and documented, but
  not enforced until the repository becomes public. Direct pushes to
  `main` are technically possible on the free private tier.
- Trivy's blocking gate on CRITICAL is fully operational — it does not
  depend on any GitHub paid feature, only on the workflow action.
- CodeQL is not running. When code scanning becomes available (public
  repo or GHAS), `codeql.yml` should be restored from the starter
  template with the `main` branch and Java 21 fixes already applied.
- The Trivy-to-Security-tab integration can be restored by re-adding
  the `upload-sarif` step from ADR 0003, once SARIF uploads work.
- All three of these choices are tier constraints, not design
  preferences. If the org upgraded, the design would execute
  unchanged.

  
---

## Update — repository made public

The repository was made public prior to submission. Code scanning
became available, and `.github/workflows/codeql.yml` was restored with
the `main` branch and Java 21 fixes applied.

The other two constraints recorded in this ADR — branch protection
enforcement and rulesets — activated automatically when the repository
went public.

The design did not change. The tier constraint lifted.
  
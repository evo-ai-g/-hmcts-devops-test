# 0006 — Azure resource tagging strategy

## Status

Accepted

## Context

Tags in Azure are not decorative. They are the primary mechanism for
cost allocation, ownership attribution, policy enforcement, and
automation. A resource without tags is a resource that appears in a
billing report with no owner and in an incident with no one to page.

Three sizes of tag set were considered:

- **Minimal (2 tags):** `environment`, `project`. Simple, but cannot
  answer "who owns this?" or "what is the data classification?".
- **Microsoft Cloud Adoption Framework full set (10+ tags):** complete,
  but reads as a checklist copy. Most tags go unused in a small stack.
- **Six-tag set:** enough to answer the operational questions that
  actually come up, few enough that every tag earns its place.

## Decision

Apply the following tags to every resource:

| Tag | Purpose | Consumer |
|---|---|---|
| `environment` | Distinguishes dev/staging/prod | Everyone — filters, policies, cost reports |
| `project` | Groups resources by workload | Cost allocation, portal search |
| `owner` | Team accountable for the resources | Incident response |
| `managed-by` | Signals "do not edit in portal" | Change control |
| `cost-centre` | Finance attribution | Finance |
| `data-classification` | UK government scheme: official / secret / top-secret | Governance, compliance |

Two implementation choices:

- `environment` is a **variable**, not a constant. The same configuration
  is deployed to dev, staging, and prod; this tag distinguishes them.
- `managed-by = "terraform"` is **hardcoded**, not a variable. It is a
  fact about how the resource was created, not a choice. Making it a
  variable would invite someone to change it.

Tags are applied via a `local.common_tags` map in `main.tf`, merged with
any resource-specific tags. This means adding a tag is one edit, not
six.

## Consequences

- Every resource can be traced to an owner and a cost centre from the
  Azure portal alone, without opening this repository.
- `managed-by = terraform` tells a human browsing the portal that the
  resource will be reverted by the next `terraform apply` if edited
  manually. Reduces the "why did my manual change disappear?" support
  ticket class.
- `data-classification = official` uses the UK government scheme
  (OFFICIAL / SECRET / TOP SECRET) rather than a generic label. This
  matches the vocabulary used by HMCTS and other UK government services.
- Enforcing these tags across all resources in a subscription would
  require an Azure Policy — out of scope for this task, but the natural
  next step in a real platform.
- Additional tags (`business-unit`, `criticality`, `ops-team`) can be
  added without changing existing consumers. The set is extensible.
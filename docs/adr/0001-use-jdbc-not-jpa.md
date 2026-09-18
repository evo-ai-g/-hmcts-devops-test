# 0001 — Use spring-boot-starter-jdbc instead of spring-boot-starter-data-jpa

## Status

Accepted

## Context

The HMCTS brief permits either `spring-boot-starter-jdbc` or
`spring-boot-starter-data-jpa`. The task explicitly states that no new
Java code is required — configuration only.

`spring-boot-starter-data-jpa` brings in Hibernate and Spring Data,
which exist to map Java objects to database tables. Without entity
classes or repository interfaces in the codebase, those libraries would
sit unused. The starter repository's `application.yaml` contains a
commented-out `spring.jpa.properties.hibernate...` block, suggesting
HMCTS's other services use JPA — but that block is not needed here.

## Decision

Use `spring-boot-starter-jdbc` with the Postgres JDBC driver declared
as `runtimeOnly`.

## Consequences

- Smaller jar, faster startup, one fewer abstraction in the image.
- No ORM: if the app later grows a domain model, this decision should
  be revisited and superseded by a new ADR.
- The commented `spring.jpa` block in `application.yaml` stays
  commented — removing it would add noise to the diff.
- The Postgres driver is `runtimeOnly` rather than `implementation`
  because no application code compiles against Postgres-specific
  classes; it only needs to be present when the connection pool opens
  a connection at runtime.
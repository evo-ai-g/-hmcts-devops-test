# syntax=docker/dockerfile:1.7

# ============================================================
# Stage 1 — build
# Full JDK + Gradle compile the app and produce a
# self-contained "fat" jar. Nothing from this stage ships
# except the jar itself.
# ============================================================
FROM eclipse-temurin:21-jdk-jammy AS builder

WORKDIR /workspace

# Copy build configuration first. This layer only invalidates
# when the Gradle wrapper or build.gradle change, so dependency
# resolution is cached across source-only edits.
COPY gradlew ./
COPY gradle ./gradle
COPY build.gradle ./
COPY config ./config

RUN sed -i 's/\r$//' ./gradlew \
 && chmod +x ./gradlew \
 && ./gradlew --no-daemon dependencies > /dev/null

# Source edits invalidate from here down.
COPY src ./src
RUN ./gradlew --no-daemon bootJar

# ============================================================
# Stage 2 — runtime
# Minimal JRE + non-root user. Only the fat jar crosses the
# stage boundary; JDK, Gradle, and source never reach the
# shipped image.
# ============================================================
FROM eclipse-temurin:21-jre-jammy AS runtime

# curl is used by HEALTHCHECK below. Installed explicitly so
# the check never silently breaks on a base-image change.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# Non-root user. UID/GID 1001 is a convention for "first
# application user" and avoids clashing with system UIDs.
RUN groupadd --system --gid 1001 app \
 && useradd  --system --uid 1001 --gid app --home-dir /app --shell /sbin/nologin app

WORKDIR /app

# Copy only the fat jar, owned by the non-root user.
COPY --from=builder --chown=app:app /workspace/build/libs/test-backend.jar /app/app.jar

USER app

EXPOSE 4000

# Wired to the actuator /health endpoint. start-period gives
# the JVM time to boot before failures start counting.
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl --fail --silent http://localhost:4000/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

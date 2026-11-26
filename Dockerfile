# syntax=docker/dockerfile:1

# Pinned versions for reproducible builds: bump them deliberately.
ARG JDK_VERSION=21.0.13.1_2-jdk-noble
ARG JRE_VERSION=21.0.13.1_2-jre-alpine-3.24

# ---- Stage 1: build the WAR with the Gradle wrapper -------------------------
# Ubuntu-based JDK: compatibility first, this stage is not shipped
FROM eclipse-temurin:${JDK_VERSION} AS build
WORKDIR /src

# Wrapper and build scripts first: the Gradle distribution, the plugins and
# the dependency metadata stay cached as long as these files are unchanged
COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle
RUN ./gradlew --no-daemon dependencies > /dev/null

# Then the main sources only, and the packaging: tests run in the CI, and
# leaving them out keeps a test change from rebuilding the WAR
COPY src/main ./src/main
RUN ./gradlew --no-daemon bootWar

# ---- Stage 2: run the WAR on a JRE ------------------------------------------
FROM eclipse-temurin:${JRE_VERSION} AS runtime
WORKDIR /app

# Unprivileged system user and group to run the application
RUN addgroup -S app && adduser -S -G app app

# The WAR name carries the version: copy whatever bootWar produced
COPY --from=build /src/build/libs/*.war app.war

USER app
EXPOSE 8080

# Exec form: java runs as PID 1 and receives the stop signal directly
ENTRYPOINT ["java", "-jar", "app.war"]

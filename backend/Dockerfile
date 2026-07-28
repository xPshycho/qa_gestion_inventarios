# syntax=docker/dockerfile:1.7

FROM eclipse-temurin:21-jdk-alpine-3.23@sha256:1ff763083f2993d57d0bf374ab10bb3e2cb873af6c13a04458ebbd3e0337dc76 AS build

WORKDIR /workspace

COPY gradlew build.gradle settings.gradle ./
COPY gradle ./gradle
RUN --mount=type=cache,target=/root/.gradle \
    chmod +x gradlew \
    && ./gradlew dependencies --no-daemon

COPY src ./src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew bootJar --no-daemon

FROM eclipse-temurin:21-jre-alpine-3.23@sha256:3f08b13888f595cc49edabea7250ba69499ba25602b267da591720769400e08c

WORKDIR /app

RUN apk upgrade --no-cache \
    && addgroup -S inventory \
    && adduser -S inventory -G inventory

COPY --from=build --chown=inventory:inventory /workspace/build/libs/*.jar app.jar

USER inventory

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

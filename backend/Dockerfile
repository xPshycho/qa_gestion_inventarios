FROM eclipse-temurin:21-jdk-alpine-3.23 AS build

WORKDIR /workspace

COPY gradlew build.gradle settings.gradle ./
COPY gradle ./gradle
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon

COPY src ./src
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:21-jre-alpine-3.23

WORKDIR /app

RUN apk upgrade --no-cache \
    && addgroup -S inventory \
    && adduser -S inventory -G inventory

COPY --from=build --chown=inventory:inventory /workspace/build/libs/*.jar app.jar

USER inventory

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

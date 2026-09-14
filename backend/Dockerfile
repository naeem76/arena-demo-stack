# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /workspace

COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
COPY src/ src/
RUN --mount=type=cache,target=/root/.m2 ./mvnw --batch-mode --no-transfer-progress -DskipTests package

FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app

RUN addgroup -S arena && adduser -S arena -G arena
COPY --from=build /workspace/target/backend-*.jar application.jar

USER arena
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/application.jar"]

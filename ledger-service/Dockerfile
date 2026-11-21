FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /build
COPY . .
RUN mvn -B -ntp -pl ledger-service -am package -DskipTests
FROM eclipse-temurin:21.0.9_10-jre-alpine
RUN addgroup -S bankcore && adduser -S -G bankcore bankcore && apk add --no-cache curl
WORKDIR /app
COPY --from=build /build/ledger-service/target/ledger-service-0.1.0-SNAPSHOT.jar app.jar
USER bankcore
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=60s CMD curl -fsS http://localhost:8080/actuator/health/readiness || exit 1
ENTRYPOINT ["java","-XX:MaxRAMPercentage=65","-jar","app.jar"]

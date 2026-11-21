FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /build
COPY . .
RUN mvn -B -ntp -pl ledger-service -am package -DskipTests
FROM eclipse-temurin@sha256:5d7689f47d670aca766b9503a70bccc2d73b4eb9221ae8f714ae958313c4ce70
RUN addgroup -S -g 10001 bankcore && adduser -S -u 10001 -G bankcore bankcore && apk add --no-cache curl
RUN chown bankcore:bankcore /tmp
VOLUME ["/tmp"]
WORKDIR /app
COPY --from=build /build/ledger-service/target/ledger-service-0.1.0.jar app.jar
USER bankcore
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=60s CMD curl -fsS http://localhost:8080/actuator/health/readiness || exit 1
ENTRYPOINT ["java","-XX:MaxRAMPercentage=65","-jar","app.jar"]

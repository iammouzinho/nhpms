FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/identity-service-0.0.1-SNAPSHOT.jar app.jar
USER 10001
EXPOSE 8081
ENTRYPOINT ["java","-jar","/app/app.jar"]

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY target/shipping-1.0.jar shipping.jar
CMD ["java", "-jar", "shipping.jar"]

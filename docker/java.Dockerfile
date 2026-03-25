FROM openjdk:17
WORKDIR /app
COPY target/shipping-1.0.jar shipping.jar
CMD ["java", "-jar", "shipping.jar"]

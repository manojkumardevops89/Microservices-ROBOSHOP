FROM eclipse-temurin:17-jre-jammy   # Uses OpenJDK 17 runtime (lightweight JRE on Ubuntu Jammy base)

WORKDIR /app                       # Creates /app directory (if not exists) and sets it as working directory

COPY target/shipping-1.0.jar shipping.jar   # Copies built JAR from local 'target' folder into container and renames it

CMD ["java", "-jar", "shipping.jar"]   # Runs the Java application when container starts

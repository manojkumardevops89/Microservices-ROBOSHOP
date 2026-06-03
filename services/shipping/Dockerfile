# Uses OpenJDK 17 runtime (lightweight JRE on Ubuntu Jammy base)
FROM eclipse-temurin:17-jre-jammy

# Creates /app directory and sets it as working directory
WORKDIR /app

# Copies built JAR from target folder into container and renames it
COPY target/shipping-1.0.jar shipping.jar

# Runs the Java application when container starts
CMD ["java", "-jar", "shipping.jar"]

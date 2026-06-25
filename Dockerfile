# ---------- STAGE 1: Build ----------
# Use an image that already has Maven + JDK 17 to build the app
FROM maven:3.9-eclipse-temurin-17 AS build

# Set working directory inside the container
WORKDIR /app

# Copy only pom.xml first (so dependency download is cached separately from code changes)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Now copy the actual source code
COPY src ./src

# Build the application, skip tests here (tests already ran in CI step earlier)
RUN mvn clean package -DskipTests

# ---------- STAGE 2: Run ----------
# Use a minimal JRE-only image (no Maven, no build tools) for the final container
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy ONLY the built JAR from the build stage, nothing else
COPY --from=build /app/target/demo-app.jar app.jar

# Document that the container listens on port 8080
EXPOSE 8080

# Command that runs when the container starts
ENTRYPOINT ["java", "-jar", "app.jar"]

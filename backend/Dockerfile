# Etapa de compilación: el JDK 21 viene en la imagen, por eso se desactiva el toolchain local
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw -B -q -DskipToolchain dependency:go-offline
COPY src src
RUN ./mvnw -B -q -DskipToolchain -DskipTests package

# Etapa de ejecución: solo el JRE y un usuario sin privilegios
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S agrovet && adduser -S agrovet -G agrovet
WORKDIR /app
COPY --from=build /app/target/agrovet-backend-*.jar app.jar
USER agrovet
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

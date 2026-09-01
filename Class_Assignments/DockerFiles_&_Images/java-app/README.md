# Java Web App

## Image

![Java container output](image.png)

## Dockerfile

```dockerfile
FROM eclipse-temurin:21-jdk

WORKDIR /app

COPY Main.java .

RUN javac Main.java

EXPOSE 8080

CMD ["java", "Main"]
```

## Commands

Build the image from the Dockerfile:

```bash
docker build -t java-webapp .
```

Run the container and map host port `8080` to container port `8080`:

```bash
docker run -d --name java-container -p 8080:8080 java-webapp
```


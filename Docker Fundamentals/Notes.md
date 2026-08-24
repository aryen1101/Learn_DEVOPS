# Docker Fundamentals

## What Is Docker?

Docker is an open-source platform for building, packaging, distributing, and running applications in lightweight, portable environments called **containers**.

A container is an isolated environment in which an application runs with its code, dependencies, and configuration.

## Why Use Docker?

Docker solves the common problem: **"It works on my machine, but not on yours."** Different computers may use different operating systems, library versions, and configurations. Docker packages the application and its dependencies together so that it runs consistently across development, testing, and production environments.

## Common Uses

1. **Consistent development environments** - Teams can use the same environment across Windows, macOS, and Linux.
2. **Application deployment** - Deploy consistently to AWS, Azure, Google Cloud, or on-premises servers.
3. **Microservices** - Run user, payment, authentication, and notification services in separate containers.
4. **Testing** - Run isolated dependencies without installing them directly on the host machine.
5. **CI/CD** - Use the same container environment to build applications, run tests, and deploy software.

Example:

```bash
docker run postgres
```

## Container vs. Virtual Machine

| Feature | Container | Virtual machine |
| --- | --- | --- |
| Virtualizes | Application environment | Entire operating system |
| Operating system | Shares the host kernel | Has its own guest OS |
| Size | Lightweight | Usually larger |
| Startup | Usually seconds | Seconds to minutes |
| Memory usage | Lower | Higher |
| Performance | Near-native | More overhead |
| Isolation | Process-level isolation | Stronger OS-level isolation |
| Examples | Docker | VMware, VirtualBox |
| Best for | Microservices and deployment | Running different operating systems |

Containers share the host OS kernel, so they are generally lighter and faster than virtual machines. Virtual machines include a complete guest operating system and provide stronger isolation.

## Docker Architecture

Docker uses a client-server architecture:

```text
User
  |
  | docker run nginx
  v
Docker CLI
  |
  | sends a request
  v
Docker Daemon (dockerd)
  |-- Creates and manages containers
  |-- Manages images, networks, and volumes
  `-- Starts and stops containers
```

### Docker CLI

The Docker CLI is the command-line client through which users send commands to the Docker daemon.

### Docker Daemon

The Docker daemon (`dockerd`) runs in the background and manages images, containers, networks, and volumes.

When you run `docker run nginx`, Docker checks for a local image, pulls it from a registry if needed, creates a container, and starts it.

### Docker Host

The Docker host is the machine on which Docker Engine runs and where containers are executed.

### Docker Registry

A Docker registry stores and distributes Docker images. **Docker Hub** is the most commonly used public registry.

## Dockerfile

A Dockerfile is a text file containing instructions used to build a Docker image.

## Image vs. Container

| Docker image | Docker container |
| --- | --- |
| A template or blueprint | A running instance of an image |
| Used to create containers | Created from an image |
| Read-only, layered filesystem | Adds a writable layer on top |
| Does not run by itself | Runs the application |
| Stored locally or in a registry | Runs on a Docker host |
| Can create many containers | Each container is a separate instance |

An image contains the application code, dependencies, and configuration required to create a container. A container is an isolated instance created from that image.

## Image Layers and Build Cache

Docker images are built layer by layer. Instructions such as `RUN`, `COPY`, and `ADD` can create filesystem layers. Docker reuses unchanged layers during later builds:

```text
node:20          -> reused
package.json     -> reused
npm install      -> reused
COPY . .         -> rebuilt when files change
```

## Container Lifecycle

### Build an image

```bash
docker build -t nodeapp .
```

### Create and run a container

```bash
docker run nodeapp
```

### Pause and resume a container

Pausing freezes the processes without terminating them.

```bash
docker pause my-container
docker unpause my-container
```

### Stop and start a container

Stopping terminates the running processes. The stopped container can be started again.

```bash
docker stop my-container
docker start my-container
```

### Remove a container

```bash
docker rm my-container
```

## Core Dockerfile Instructions

| Instruction | Purpose | Example |
| --- | --- | --- |
| `FROM` | Specifies the base image | `FROM node:20` |
| `WORKDIR` | Sets the working directory | `WORKDIR /app` |
| `COPY` | Copies files from the host into the image | `COPY . .` |
| `ADD` | Copies files with additional features | `ADD app.tar.gz /app` |
| `RUN` | Executes a command while building the image | `RUN npm install` |
| `EXPOSE` | Documents the container port | `EXPOSE 3000` |
| `CMD` | Sets the default startup command | `CMD ["npm", "start"]` |
| `ENTRYPOINT` | Defines the main executable | `ENTRYPOINT ["node"]` |
| `ENV` | Sets an environment variable | `ENV NODE_ENV=production` |
| `ARG` | Defines a build-time variable | `ARG VERSION=1.0` |
| `LABEL` | Adds image metadata | `LABEL author="Aryen"` |
| `USER` | Sets the user for commands and the container | `USER node` |
| `VOLUME` | Defines a mount point | `VOLUME /data` |

# Docker Concepts

## What Is Docker?

Docker is an open-source platform for building, packaging, distributing, and running applications in lightweight, portable environments called **containers**.

A container is an isolated process that includes an application and its dependencies. Containers share the host operating system's kernel, which makes them lighter than virtual machines.

## Why Use Docker?

- Consistent development, testing, and production environments
- Portable application deployment
- Isolated services for microservices
- Repeatable CI/CD builds and tests
- No need to install every dependency directly on the host

Example:

```bash
docker run postgres
```

## Container vs. Virtual Machine

| Feature | Container | Virtual machine |
| --- | --- | --- |
| Virtualizes | Application environment | Entire operating system |
| Operating system | Shares the host kernel | Has its own guest OS |
| Size and startup | Usually smaller and faster | Usually larger and slower |
| Memory usage | Lower | Higher |
| Isolation | Process-level isolation | Stronger OS-level isolation |
| Examples | Docker | VMware, VirtualBox |
| Best for | Portable applications and services | Running different operating systems |

## Docker Architecture

Docker uses a client-server architecture:

```text
Docker CLI -> Docker daemon (dockerd) -> Images, containers, networks, and volumes
```

- **Docker CLI:** The command-line client used to send commands.
- **Docker daemon:** Runs in the background and manages Docker objects.
- **Docker host:** The machine where Docker Engine runs.
- **Docker registry:** Stores and distributes images. Docker Hub is a common public registry.

When `docker run nginx` is executed, Docker uses the local image if available, pulls it from a registry if necessary, creates a container, and starts it.

## Dockerfile

A Dockerfile is a text file containing instructions used to build a Docker image.

## Image vs. Container

| Docker image | Docker container |
| --- | --- |
| Read-only template used to create containers | Isolated instance created from an image |
| Contains application code and dependencies | Adds a writable layer at runtime |
| Stored locally or in a registry | Runs on a Docker host |
| One image can create many containers | Each container is a separate instance |

## Image Layers and Build Cache

Docker builds images in layers. Instructions such as `RUN`, `COPY`, and `ADD` can create layers. Unchanged layers are reused during later builds.

```text
node:20          -> reused
package.json     -> reused
npm install      -> reused
COPY . .         -> rebuilt when files change
```

## Container Lifecycle

### Build, create, and run

```bash
docker build -t nodeapp .
docker run nodeapp
```

### Pause and resume

Pausing freezes the processes in a running container without terminating them.

```bash
docker pause my-container
docker unpause my-container
```

### Stop and start

Stopping terminates the running processes, but the stopped container can be started again.

```bash
docker stop my-container
docker start my-container
```

Stop all running containers:

```bash
docker stop $(docker ps -q)
```

### Remove a container

```bash
docker rm my-container
```

## Core Dockerfile Instructions

| Instruction | Purpose | Example |
| --- | --- | --- |
| `FROM` | Selects the base image | `FROM node:20` |
| `WORKDIR` | Sets the working directory inside the image | `WORKDIR /app` |
| `COPY` | Copies files from the build context | `COPY . .` |
| `ADD` | Copies files and supports features such as local archives | `ADD app.tar.gz /app` |
| `RUN` | Executes a command while building | `RUN npm install` |
| `EXPOSE` | Documents a container port | `EXPOSE 3000` |
| `CMD` | Sets the default startup command; can be overridden | `CMD ["npm", "start"]` |
| `ENTRYPOINT` | Sets the main executable | `ENTRYPOINT ["node"]` |
| `ENV` | Sets an environment variable | `ENV NODE_ENV=production` |
| `ARG` | Defines a build-time variable | `ARG VERSION=1.0` |
| `LABEL` | Adds image metadata | `LABEL author="Aryen"` |
| `USER` | Sets the user for build steps and runtime | `USER node` |
| `VOLUME` | Declares a mount point | `VOLUME /data` |

## Common Docker Commands and Concepts

### Removing resources

- `rm` is a shell command for deleting files on the host.
- `docker rm` removes containers. `docker rm -f` forcefully stops and removes a running container.
- `docker rmi` or `docker image rm` removes images.

Usually, remove dependent containers before removing their image:

```bash
docker stop my-container
docker rm my-container
docker rmi nginx:latest
```

Forcing image removal does not remove containers. Remove unwanted containers separately.

### Pruning unused resources

These commands delete unused resources, so review the confirmation prompt:

```bash
docker system df
docker container prune       # stopped containers
docker image prune            # dangling images
docker image prune -a         # images unused by any container
docker system prune           # stopped containers, unused networks, dangling images, build cache
docker system prune -a        # more aggressive image cleanup
```

### Start, restart, and inspect

```bash
docker start <container>
docker restart <container>
docker inspect <image_name_or_id>
docker inspect <container_name_or_id>
```

`docker start` starts an existing stopped container. `docker restart` stops and starts it again. `docker inspect` displays low-level JSON metadata.

### Execute commands in a running container

```bash
docker exec <container_name_or_id> <command>
docker exec -it my-container /bin/bash
```

Use `/bin/sh` if Bash is not available. `-i` keeps standard input open and `-t` allocates a terminal.

### Common flags

- `-d`: Runs in detached mode.
- `-p <host_port>:<container_port>`: Publishes a container port, for example `-p 8080:80`.
- `-t` with `docker build`: Assigns an image name and optional tag, for example `-t nodeapp:1.0`.

`EXPOSE` documents a port; it does not publish it. Use `-p` with `docker run` to publish the port.

## Multi-stage Dockerfiles

A multi-stage Dockerfile uses multiple `FROM` stages. One stage builds the application, and a later stage copies only the required output into a smaller runtime image.

```dockerfile
FROM node:20 AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine AS runtime
COPY --from=build /app/dist /usr/share/nginx/html
```

The final image contains the built application and Nginx, not the Node.js build tools used only during the build.

## Docker Networks

Check available networks:

```bash
docker network ls
```

A network driver determines how Docker creates a network and how containers communicate through it.

| Driver | Purpose |
| --- | --- |
| `bridge` | Connects containers on the same Docker host |
| `host` | Uses the host's network directly |
| `none` | Provides only loopback connectivity |
| `overlay` | Connects containers across multiple Docker hosts |

### Bridge network

The default `bridge` network connects containers on the same Docker host. A user-defined bridge network also provides automatic DNS resolution between containers.

```bash
docker run -d --name web -p 8080:80 nginx
docker network create mynetwork
docker run -d --name web2 --network mynetwork nginx
```

On the default bridge network, containers should use IP addresses for container-to-container communication. On a user-defined bridge network, containers can communicate by name.

### Host network

On Linux, a container using the host network shares the host's network namespace. Port publishing is not needed.

```bash
docker run -d --network host nginx
```

### None network

The container has no external network interface, except for loopback, and cannot communicate with other containers.

```bash
docker run -d --network none nginx
```

### Overlay network

An overlay network connects containers on different Docker hosts and is commonly used with Docker Swarm.

```bash
docker network create -d overlay my-overlay
```

The overlay network has global scope; other network types normally have local scope.

### Network management

```bash
docker network inspect <network-name-or-id>
docker network connect <network-name> <container>
docker network rm <network-name-or-id>
```

One container can connect to multiple networks. For example, a backend container can connect to both a frontend network and a database network. Containers on different user-defined networks cannot communicate by default.

## Docker Volumes

A Docker volume stores data outside a container's writable layer. The data remains when the container is deleted, which is especially useful for databases.

```bash
docker volume create <volume-name>
docker volume ls
docker run -d --name alpine-data -v mydata:/data alpine
docker volume inspect <volume-name-or-id>
docker volume rm <volume-name-or-id>
```

In `mydata:/data`, `mydata` is the volume name and `/data` is the mount path inside the container. Data written to that path is stored in the volume. Deleting the volume normally deletes its data permanently.

## Bind Mounts

A bind mount connects a specific file or folder on the host directly to a path inside a container. Unlike a Docker volume, its location is chosen by the user.

```bash
docker run -d --name web -v /path/on/host:/usr/share/nginx/html nginx
```

Changes made on the host are immediately visible inside the container, and changes made in the container are visible on the host.


Docker-Compose ->
Docker Compose is a tool used to define and run multiple Docker containers as one application using a YAML file, usually compose.yaml.
Instead of running many docker run commands manually, you describe everything in one file.

Docker Swarm

Docker Swarm is Docker's built-in container orchestration system. It allows you to combine multiple Docker hosts (machines) into a cluster and manage containers across them.

Without Swarm:

Docker Host 1 → containers
Docker Host 2 → containers
Docker Host 3 → containers

With Swarm:

              Docker Swarm
                   │
       ┌───────────┼───────────┐
       ↓           ↓           ↓
    Host 1       Host 2       Host 3
   Manager       Worker       Worker
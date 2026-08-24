# Introduction to DevOps & Microservices

## 1) Monolith vs Microservices

| Aspect | Monolithic Architecture | Microservices Architecture |
| --- | --- | --- |
| Structure | Whole application is one codebase | Application is split into small services |
| Deployment | One deployment for the whole app | Each service can be deployed separately |
| Scalability | Scale the whole application | Scale only the required service |
| Development | Simple for small teams | Better for large teams working in parallel |
| Technology | Usually one stack | Different services can use different stacks |
| Maintenance | Easier at first, harder when it grows | More complex at first, easier for large systems |
| Failure impact | One bug can affect the whole app | One service failure usually does not break everything |
| Communication | Internal function calls | Network calls like REST, gRPC, or messaging |
| Testing | Easier to test end to end | Needs integration and contract testing |
| Performance | Faster internal calls | Slight network overhead |

## 2) What is DevOps?

DevOps is a mix of Development and Operations. It uses practices and tools to make software delivery faster, more reliable, and more automated.

## 3) Common DevOps Tools

- Git and GitHub: source code management and collaboration
- Docker: package applications in containers
- Linux: common operating system used in DevOps
- Networking: useful for understanding TCP, UDP, and OSI layers
- CI/CD: automate code testing, building, and deployment
- Kubernetes: manage and scale containers
- Terraform: create infrastructure using code
- Ansible: automate server setup and configuration
- Grafana and Prometheus: monitor systems and applications
- GitOps: manage deployments using Git as the source of truth
- SonarQube: check code quality and find bugs or code smells
- Trivy: scan for security vulnerabilities in images, files, and configs

## 4) CI/CD

CI/CD means:

- CI: Continuous Integration
- CD: Continuous Delivery or Continuous Deployment

Simple pipeline:

Code -> Test -> Build -> Deploy

### Continuous Delivery

The code is ready for production, but a human approves the final deployment.

### Continuous Deployment

The code is deployed automatically after passing tests.

## 5) Cloud

Cloud means using servers, storage, databases, and networking over the internet instead of owning the hardware yourself.

Examples: AWS, Azure, GCP, Oracle Cloud

## 6) Kubernetes

Kubernetes, or K8s, is used to deploy, manage, and scale containerized applications.

## 7) Terraform

Terraform is an infrastructure-as-code tool. It helps create and manage cloud resources using code instead of manual clicks.

It is useful for keeping the same setup across:

- Development
- Testing
- Production

## 8) Ansible

Ansible automates server tasks like installing software, changing settings, and deploying apps.

It uses playbooks, usually written in YAML.

## 9) Monitoring Tools

Grafana and Prometheus are used to monitor systems, track metrics, and observe application health.

## 10) Security in DevOps

### DevSecOps

DevSecOps means adding security into the DevOps process.

### SecOps

SecOps focuses on combining security and operations.

### SonarQube

SonarQube checks source code for bugs, vulnerabilities, and code quality issues.

### Trivy

Trivy scans container images, file systems, Git repositories, Kubernetes configs, and infrastructure files for vulnerabilities.

## 11) DevOps Lifecycle

Plan -> Code -> Build -> Test -> Deploy -> Release -> Operate -> Monitor

- Plan: decide what to build
- Code: write the application
- Build: create the build or container image
- Test: check features, unit tests, and security tests
- Deploy: move the app to the target environment
- Release: make it available to users
- Operate: keep the system running
- Monitor: watch health, logs, and performance

## 12) Common DevOps Job Roles

- DevOps Engineer: automates build, test, and deployment work
- DevSecOps Engineer: adds security into the DevOps process
- Platform Engineer: builds internal platforms for developers
- SRE (Site Reliability Engineer): focuses on reliability and uptime
- Cloud Engineer: works with cloud infrastructure and services
- Solution Architect: designs the overall system
- AIOps Engineer: uses AI to improve operations
- MLOps Engineer: automates machine learning deployment and operations
- AI Cloud Engineer: works on cloud systems for AI workloads

## 13) Telnet

Telnet is a network troubleshooting command used to check whether a port is reachable.

Example:

`telnet google.com 80`

This tries to open a TCP connection to port 80.

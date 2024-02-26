# ocp-dev-101

## Configuration

Install OpenShift Gitops and Tekton Operators.
TODO: install using sh script for OpenShift GitOps and use argo for Tekton

## Demos

### Demo 1: Run Locally

Take a look at quarkus app *lol-champions-app* and execute the following steps:

- Run tests witn in-memory DB
```sh
# Review Quarkus APP code

# App directory
# TODO: USE GITEA REFERENCE
cd lol-champions-app

# Run tests
mvn clean test
```
- Run app on dev mode, will fail due there is no DB running locally
```sh
mvn compile quarkus:dev
```
- Start a Postgres DB locally on a container
```sh
# Start podman
podman machine start

#Start DB
podman run -d --name lol-app-db \
  -e POSTGRES_USER=develop \
  -e POSTGRES_PASSWORD=develop \
  -e POSTGRES_DB=lol-app-db \
  -p 5432:5432 \
  postgres:10.5

# Check DB is running
podman ps
```
- Run application as a process
```sh
mvn compile quarkus:dev
```
- Build image and run as a container
```sh
# Stop and remove postgres db
podman stop lol-app-db
podman rm lol-app-db

# Create a network for testing locally
podman network create lol-net

# Recreate the database 
podman run -d --name lol-app-db --network=lol-net \
  -e POSTGRES_USER=develop \
  -e POSTGRES_PASSWORD=develop \
  -e POSTGRES_DB=lol-app-db \
  -p 5432:5432 \
  postgres:10.5

# Build image using a Dockerfile
mvn clean package -DskipTests
podman build . -t lol-app:0.0.1

# Review image
podman images

# Run image as a container and validate logs
podman run -i --rm -d -p 8080:8080 --name lol-app --network=lol-net lol-app:0.0.1
podman logs -f lol-app

# Open locally

# Clean up
podman stop lol-app lol-app-db
podman ps -a
podman rm lol-app-db
```

### Demo 2: Run in Openshift (single pod)

Deploy the application on OpenShift as a pod, what is missing here?

NOTE: Dabases is already deployed in the namespace via ArgoCD (reviewed later)

- Upload application image to Quay
- Create a pod that uses uploaded image
- 

### Demo 3: Develop application using OpenShift DevSpaces

### Demo 4: Create application using OpenShift s2i

### Demo 5: Tekton, automate CI

### Demo 6: ArgoCD automate CD


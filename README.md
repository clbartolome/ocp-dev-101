# ocp-dev-101

## Configuration

Install OpenShift Gitops, Devspaces and Tekton Operators.
TODO: install using sh script for OpenShift GitOps and use argo for Tekton and Devspaces

## Demos

### Demo 1: Run Locally

In this demo we're going to run locally a Quarkus application.

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
mvn clean package -DskipTests -Dquarkus.profile=dev-podman
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

### Demo 2: Run in Openshift

In this demo we're going to manually deploy the application and it's database (ephemeral) in an OCP namespace.
NOTE: during the demo, review how to do all the steps in the 'developer console' before running the commands.

Execute the following steps:

- Upload image to Quay
```sh
# login into quay
podman login quay.io

# Tag image on Quay repository and push image
podman tag lol-app:0.0.1 quay.io/calopezb/lol-app:1.0.0
podman push quay.io/calopezb/lol-app:1.0.0

# Login into quay and change lol-app 'Repository Visibility' to 'public' - review tags
```

- Create an ephemeral database
```sh
# Login into your terminal with oc login and access demo-single-pod namespace
oc project demo-single-pod

# Create an ephemeral postgresql db
oc new-app postgresql-ephemeral \
  -p DATABASE_SERVICE_NAME=lol-app-db \
  -p POSTGRESQL_USER=develop \
  -p POSTGRESQL_PASSWORD=develop \
  -p POSTGRESQL_DATABASE=lol-app-db

# Deploy lol-app using Quay image
oc new-app --name=lol-app quay.io/calopezb/lol-app:1.0.0

# Review logs, terminal,...

# Expose SVC to generate a route
oc expose svc lol-app

# Access app using route
```

### Demo 3: Develop application using OpenShift DevSpaces

### Demo 4: Create application using OpenShift s2i

In this demo we'll create the application image using s2i process
NOTE: Review build procesess on OpenShift and base images
NOTE: Execute this commands after showing how would it be on the 'Developer Console'

Follow these steps:
```sh
# Login into your terminal with oc login and access demo-single-pod namespace
oc project demo-s2i

# Review image for jdk 17
oc get is -n openshift | grep jdk-17

# Create application using s2i
oc new-app --name=lol-app \
  openshift/ubi8-openjdk-17:1.12~http://gitea.gitea.svc.cluster.local:3000/gitea/lol-champions-app \
  --strategy=source --as-deployment-config=false

# Review buildconfig and logs (why is failing)
oc get pods
oc logs -f lol-app-xxxxx

# Create configuration map
oc create cm lol-app-config --from-literal DB_HOST=lol-app-db --from-literal DB_PORT=5432 --from-literal DB_NAME=lol-app-db
oc get cm lol-app-config -o yaml

# Create secret
oc create secret generic lol-app-secured  --from-literal DB_USER=user --from-literal DB_PASS=pass
oc get secret lol-app-secured -o yaml
echo cGFzcw== | base64 -d

# Configure cm and secret as environment variables in the deployment
oc set env deploy/lol-app --from cm/lol-app-config
oc set env deploy/lol-app --from secret/lol-app-secured

# Review the deployment and the pod
oc get deploy lol-app -o yaml
oc get pods
oc rsh lol-app-xxxxx


# Expose service
oc expose svc lol-app
oc get route
```


### Demo 5: Tekton, automate CI

### Demo 6: ArgoCD automate CD


clean

delete image on quay
delete 


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
> NOTE: during the demo, review how to do all the steps in the 'developer console' before running the commands.

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
> NOTE: Review build procesess on OpenShift and base images
> NOTE: Execute this commands after showing how would it be on the 'Developer Console'

Follow these steps:

- Login and review available s2i images:
```sh
# Login into your terminal with oc login and access demo-single-pod namespace
oc project demo-s2i

# Review image for jdk 17
oc get is -n openshift | grep jdk-17
```

- Deploy application:
```sh
# Create application using s2i
oc new-app --name=lol-app \
  openshift/ubi8-openjdk-17:1.12~http://gitea.gitea.svc.cluster.local:3000/gitea/lol-champions-app \
  --strategy=source --as-deployment-config=false

# Review buildconfig and logs (why is failing)
oc get pods
oc logs -f lol-app-xxxxx
```

- Add configuration:
```sh
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
```

- Expose application:
```sh
# Expose service
oc expose svc lol-app
oc get route
```

- Tune the developer console view
```sh
# Add labels
oc label deploy lol-app \
  app.kubernetes.io/part-of=lol-champions \
  app.openshift.io/runtime=quarkus

# Add annotations to link app with the DB
oc annotate deploy lol-app app.openshift.io/connects-to='[{"apiVersion":"apps/v1","kind":"Deployment","name":"lol-app-db"}]'
```


### Demo 5: Tekton, automate CI

In this demo we're going to perfom a basic review of how Tekton works and review an example of a CI pipieline.
> NOTE: tkn client required!

- Create a namespace:
```sh
oc new-project tekton-overview
```

- Create a task for printing a message:
```sh
cat << EOF | oc apply -f  -
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: demo-task
spec:
  params:
    - name: MESSAGE
  results:
    - name: MESSAGE_DATE
  steps:
    - name: print-message
      image: registry.access.redhat.com/ubi8/ubi-minimal:8.3
      script: |
        echo $(params.MESSAGE)
    - name: get-date
      image: registry.access.redhat.com/ubi8/ubi-minimal:8.3
      script: |
        DATE=$(date)
        echo $DATE > $(results.MESSAGE_DATE.path)
        echo $DATE
EOF
```

- Create and test the task:

```sh
tkn task list
tkn task start demo-task
tkn taskrun logs demo-task-run-j662m -f -n tekton-overview
oc get pods
oc logs demo-task-run-xxxxx-pod
oc logs demo-task-run-xxxxx-pod -c step-print-message
oc logs demo-task-run-xxxxx-pod -c step-maven-version
```

- Create a pipeline:

```sh
cat << EOF | oc apply -f  -
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: demo-pipeline
spec:
  params:
    - name: MESSAGE
  tasks:
    - name: task-1
      taskRef:
        kind: Task
        name: demo-task
      params:
        - name: MESSAGE
          value: $(params.MESSAGE)
    - name: task-2
      runAfter:
        - task-1
      taskRef:
        kind: Task
        name: demo-task
      params:
        - name: MESSAGE
          value: "$(tasks.task-1.results.MESSAGE_DATE)"
EOF
```

- Create and test the pipeline:

```sh
tkn pipeline list
tkn pipeline start demo-pipeline
tkn pipelinerun logs demo-pipeline-run-xxxxx -f -n tekton-overview
tkn pipeline list
oc get pods
```

- Cleanup:
```sh
oc delete tekton-overview
```

- Review the pipelines created in **demo-tekton** namespace.
- Configure webhook
- Make an update in application
- Follow the triggered pipeline in OpsnShift console

### Demo 6: ArgoCD automate CD


clean

delete image on quay
delete 


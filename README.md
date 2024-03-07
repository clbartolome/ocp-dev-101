# ocp-dev-101

## Configuration

Install OpenShift Gitops, Devspaces and Pipelines Operators.
TODO: install using sh script for OpenShift GitOps and use argo for Tekton and Devspaces

### LOL Champios Application main image

Apart from the images created in this demo, there is a main image for LOL Champions application in: *quay.io/demo-applications/lol-champions*

The image has been built using OpenShift S2I process and the following commands to pull from OpenShift internal registry and upload to Quay:

```sh
# Expose internal registry
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

# Get Openshift hostn and login into the registry
HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
podman login -u <user> -p $(oc whoami -t) $HOST

# Pull and push the image into Quay
podman pull $HOST/demo-s2i/lol-app --tls-verify=false
podman images
podman tag $HOST/demo-s2i/lol-app:latest quay.io/demo-applications/lol-champions:1.0.0
podman push quay.io/demo-applications/lol-champions:1.0.0
```

## Demos

### Demo 1: Run Locally

In this demo we're going to run locally a Quarkus application.

Take a look at quarkus app *lol-champions-app* and execute the following steps:

- Go to Gitea Namespace and open URL. Login using credentials gitea/openshift
- Clone gitea lol-champions app repository and open it
```sh
# Create a temporary folder
mkdir ~/Desktop/deleteme/demo
cd ~/Desktop/deleteme/demo

# Clone repo
git clone <gitea_url>/gitea/lol-champions-app

# Open editor
code lol-champions-app
```
- Review code (pom, code, properties, tests)
- Run tests witn in-memory DB
```sh
# App directory
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
- Validate on a web browser:
  - root
  - /q/health/live
  - wrong url to see the error dev page
  - Make a change to se how is automatically reloaded. For example add a rest endpoint in ChampionResource:
  ```java
  @GET
  @Path("/test")
  @Produces(MediaType.APPLICATION_JSON)
  public Response getTest() {

    return Response.ok("everything is fine").build();
  }
  ```
  - Revert changes
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

# Check DB is running
podman ps

# Build image using a Dockerfile (review docker file while building)
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

### Demo 2: Develop application using OpenShift DevSpaces

In this demo we're goint to review how DevSpaces can simplify the developmemnt process by integrating all required integrations and tools.

- Review Application *devfile*
- Go to OpenShift and open quick access link to *Red Hat OpenShift DevSpaces
- Login with your OCP user
- Click *Add WorkSpace*
- Introduce the repository URL - `https://github.com/clbartolome/ocp-dev-101` - Create & Open
- Wait until devspace is ready and review:
  - Review the code + git
  - Review tasks (F1 - Tasks:run tasks - devfile)
  - Review pod to understand there is a local Postgresql instance:
  ```sh
  # Open namespace
  oc project <user>-devspaces
  
  # Review pods
  oc get pods
  oc describe pod workspacesxxxxxx

  # Open logs for postgres
  oc get logs workspacesxxxxxx -c postgres
  ```
  - Review dev:quarkus and open endpoints
  - Stop/Delete namespace


### Demo 3: Run in Openshift

In this demo we're going to manually deploy the application and it's database (ephemeral) in an OCP namespace.
> NOTE: during the demo, review how to do all the steps in the 'developer console' before running the commands.

Execute the following steps:

- Upload image to Quay
```sh
# login into quay
podman login quay.io

# Tag image on Quay repository and push image
podman images
podman tag lol-app:0.0.1 quay.io/calopezb/lol-app:1.0.0
podman push quay.io/calopezb/lol-app:1.0.0

# Login into quay and change lol-app 'Repository Visibility' to 'public' - review tags
```

- Create an ephemeral database
```sh
# Login into your terminal with oc login and access demo-manual-deploy namespace
oc project demo-manual-deploy

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

### Demo 4: Create application using OpenShift s2i

In this demo we'll create the application image using s2i process
> NOTE: Review build procesess on OpenShift and base images
> NOTE: Execute this commands after showing how would it be on the 'Developer Console'

Follow these steps:

- Login and review available s2i images:
```sh
# Login into your terminal with oc login and access demo-s2i namespace
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
oc logs lol-app-1-build -f
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

- Create a namespace and a folder locally:
```sh
oc new-project tekton-overview

mkdir ~/Desktop/deleteme/tekton
cd ~/Desktop/deleteme/tekton
```

- Create a task for printing a message:
```sh
cat << EOF | oc apply -f  -
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: demo-task-asd
spec:
  params:
    - name: MESSAGE
  results:
    - name: MESSAGE_DATE
  steps:
    - name: print-message
      image: registry.access.redhat.com/ubi8/ubi-minimal:8.3
      script: |
        echo "$(params.MESSAGE)"
    - name: get-date
      image: registry.access.redhat.com/ubi8/ubi-minimal:8.3
      script: |
        DATE="$(date)"
        echo $DATE > "$(results.MESSAGE_DATE.path)"
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
- Retrieve webhook service url:
```sh
# Access demo-tekton namespace
oc project demo-tekton

# Review created service
oc get svc
```

- Configure gitea webhooks for application push events in master branch (using installation information values):
  - Open Gitea and login.
  - Open `lol-champions-app`
  - Create a webhook in `Settings > Webhooks > Add Webhook`
  - Target URL must be *http://el-trigger-build-listener.demo-tekton.svc.cluster.local:8080*
  - HTTP Method must be `POST`
  - POST Content Type must be `application/json`
  - Secret can be any value
  - Trigger On `Push Events`

- Make an update in application like changing POM version
- Follow the triggered pipeline in OpsnShift console
> NOTE: Application will fail to deploy because there is no DB. Challenge yourself and deploy a Postgresql db and connect lol-app using a configurationMap and a secret.

### Demo 6: ArgoCD automate CD

For the last demo we're going to use 3 logical environments for our application:
- demo-dev (empty)
- demo-test (1 replica of lol-app - handled by ArgoCD)
- demo-prod (3 replicas of lol-app - handled by ArgoCD)

> NOTE: All environments have a DB already deployed (Prod database is in a separate namespace)

Follow these instructions:
- To create *dev* resources use the deployment done in *demo-s2i*:
```sh
# Login into your terminal with oc login and access demo-s2i namespace
oc project demo-s2i
```
- Clone lol-champions-deploy repository and review it
```sh
# Get Gitea URL
HOST=http://$(oc get route gitea -n gitea --template='{{ .spec.host }}')
git clone $HOST/gitea/lol-champions-deploy

# Reiview
cd lol-champions-deploy/deploy
tree lol-app
```
- Create a new folder for dev
> NOTE: this could be deploy as part of the kustomization done for test and prod, but we're going to use a separate directory for demo purpose
```sh
mkdir argo-demo
```

- Get application deployment
```sh
oc get deploy lol-app -o yaml > argo-demo/deployment.yaml
vi argo-demo/deployment.yaml
```
  Cleanup deployment:
  - Delete everything in `metadata` but `metadata.name` , `metadata.label` and `metadata.annotations` (connect to)
  - Delete everything in `spec` but:
    - `spec.replicas`
    - `spec.template`
  - Delete everything in `spec.template` but:
    - `spec.replicas`
    - `spec.template`
  - Delete everything in `spec.template.spec.containers` but:
    - `spec.template.spec.containers.name`
    - `spec.template.spec.containers.image` (replace by `quay.io/demo-applications/lol-champions:1.0.0`)
    - `spec.template.spec.containers.imagePullPolicy`
    - `spec.template.spec.containers.livenessProbe`
    - `spec.template.spec.containers.ports` leave just 8080
    - `spec.template.spec.containers.readinessProbe` leave just 8080
  - Delete everything in `status`
  
- Download service:
```sh
oc get svc lol-app -o yaml > argo-demo/service.yaml
vi argo-demo/service.yaml
```

  Cleanup service:
  - Delete everything in `metadata` but `metadata.name`
  - Delete everything in `spec` but `spec.ports` and leave just 8080
  - Delete everything in `status`

- Download route:
```sh
oc get route lol-app -o yaml > argo-demo/route.yaml
vi argo-demo/route.yaml
```

  Cleanup route
  - Delete everything in `metadata` but `metadata.name`
  - Delete everything in `spec` but:
    - `spec.to`
    - `spec.port`
  - Delete everything in `status`

- Download cm:
```sh
oc get cm lol-app-config -o yaml > argo-demo/cm.yaml 
vi argo-demo/cm.yaml
```

  Cleanup cm
  - Delete everything in `metadata` but `metadata.name`
  - Delete everything in `status`

- Download secret:
```sh
oc get secret lol-app-secured -o yaml > argo-demo/secret.yaml
vi argo-demo/secret.yaml
```

  Cleanup secret:
  - Delete everything in `metadata` but `metadata.name`
  - Delete everything in `status`

- Push changes
```sh
# Add files
git add .
git status

# Commit and push
git commit -m "included dev deployment"
git push
```
- Create ArgoCD application
  - Access argoCD
  - Click **+ NEW APP** button
  - Use this values:
    - Application Name: `lol-app-dev`
    - Project Name: `default`
    - Sync Policy: Automatic (with self heal)
    - Source:
      - Repository URL: `http://gitea.gitea.svc.cluster.local:3000/gitea/lol-champions-deploy`
      - Revision: `master`
      - Path: `deploy/argo-demo`
    - Destination:
      - Cluster URL: `https://kubernetes.default.svc`
      - Namespace: `demo-dev`
- Review deployment and application
- Test deployment is working fine
- Prod deployment is failing, why?
  - Looks like App is not able to connect with the DB
  - Review **prod** deployment, there is a network policy that denies all external traffic into the DB namespace
  - Modify the existing NP:
  ```yaml
  kind: NetworkPolicy
  apiVersion: networking.k8s.io/v1
  metadata:
    name: deny-by-default
  spec:
    podSelector: {}
    policyTypes:
      - Ingress
    ingress:
      - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: demo-prod
  ```



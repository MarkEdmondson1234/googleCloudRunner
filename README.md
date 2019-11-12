# cloudRunner

[![Build Status](https://travis-ci.org/MarkEdmondson1234/cloudRunner.svg?branch=master)](https://travis-ci.org/MarkEdmondson1234/cloudRunner)
[![codecov](https://codecov.io/gh/MarkEdmondson1234/cloudRunner/branch/master/graph/badge.svg)](https://codecov.io/gh/MarkEdmondson1234/cloudRunner)

As easy as possible R scripts in the cloud, via Cloud Run, Cloud Build and Cloud Scheduler.  Continuous Development and Integration tools on Google Cloud Platform.

## Ambition

Point your R code at a function, that automatically deploys and runs it in the GCP cloud via an API endpoint.

## Usage

Set up auth, environment arguments etc. as per bottom of this file.

### R APIs

1. Make an R API via [plumber](https://www.rplumber.io/) that contains entry file api.R.  You can use the demo example in `inst/example` if you like.
2. Deploy via the `cr_deploy()` function:

```r
library(cloudRunner)

cr <- cr_deploy("api.R")
#2019-11-12 10:34:29 -- File size detected as 903 bytes
#2019-11-12 10:34:31> Cloud Build started - logs: 
#https://console.cloud.google.com/gcr/builds/40343fd4-6981-41c3-98c8-f5973c3de386?project=1080525199262

#Waiting for build to finish:
# |===============||
#Build finished
#2019-11-12 10:35:43> Deployed to Cloud Run at: 
#https://cloudrunnertest2-ewjogewawq-ew.a.run.app
#==CloudRunService==
#name:  cloudrunnertest2 
#location:  europe-west1 
#lastModifier:  1080525199262@cloudbuild.gserviceaccount.com 
#containers:  gcr.io/mark-edmondson-gde/cloudrunnertest2 
#creationTimestamp:  2019-11-12T10:35:19.993128Z 
#observedGeneration:  1 
#url:  https://cloudrunnertest2-ewjogewawq-ew.a.run.app 
```

Deployment via `cr_deploy()` automated these steps:
1. Creates a Dockerfile for your R script if necessary using [`containerit`](https://o2r.info/containerit/index.html)
2. Uploads the Dockerfile and your api.R file to your Google Cloud Storage bucket
3. Creates a Cloud Build job for building the files uploaded to the GCS bucket, and pushes the Docker images to Google Container Registry
3. Deploys that container to Cloud Run

It will launch a browser showing the build on Cloud Build, or you can wait for progress in your local R sesion.  Upon successfully deployment it gives you a `CloudRunService` object with details of the deployment. 

All the above stages can be customised for your own purposes, using the functions explained below.

### Run R builds

Cloud Run is only necessary if you want a URL endpoint for your script.  You can run other scripts within Cloud Build that can be triggered one time, setup to trigger on GitHub events or pub/sub, or scheduled using Cloud Scheduler.

Cloud Build uses containers to run everything.  This means it can run almost any language/program or application including R. Having an easy way to create and trigger these builds from R means R can serve as a UI or gateway to any other program e.g. R can trigger a Cloud Build using `gcloud` to deploy Cloud Run applications.

Cloud Build is centered around the [cloudbuild.yaml format](https://cloud.google.com/cloud-build/docs/build-config) - you can use existing cloudbuild.yaml files or create your own in R using the yaml helper functions.

An example cloudbuild.yaml is shown below - this outputs the versions of docker and gcloud it is using:

```yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  id: Docker Version
  args: ["version"]
- name: 'alpine'
  id:  Hello Cloud Build
  args: ["echo", "Hello Cloud Build"]
```

This cloudbuild.yaml file can be built directly via the `cr_build()` function:

```r
b1 <- cr_build("cloudbuild.yaml")
```
The build will trigger a webpage to the build logs to open.  Or you can set this to false and wait in R for the build:

```r
b2 <- cr_build("cloudbuild.yaml", launch_browser = FALSE)
cr_build_wait(b2)
# Waiting for build to finish:
#  |===||
# Build finished
# ==CloudBuildObject==
# buildId:  c673143a-794d-4c69-8ad4-e777d068c066 
# status:  SUCCESS 
# logUrl:  https://console.cloud.google.com/gcr/builds/c673143a-794d-4c69-8ad4-e777d068c066?project=1080525199262 
# steps: 
#  name:
# - gcr.io/cloud-builders/docker
# - alpine
# args:
# - version
# - - echo
#   - Hello Cloud Build
# id:
# - Docker Version
# - Hello Cloud Build
# timing:
#   startTime:
#   - '2019-11-12T11:16:37.682826707Z'
#   - '2019-11-12T11:16:38.585221812Z'
#   endTime:
#   - '2019-11-12T11:16:38.585157179Z'
#   - '2019-11-12T11:16:40.680755419Z'
# status:
# - SUCCESS
# - SUCCESS
# pullTiming:
#   startTime:
#   - '2019-11-12T11:16:37.682826707Z'
#   - '2019-11-12T11:16:38.585221812Z'
#   endTime:
#   - '2019-11-12T11:16:37.740729198Z'
#   - '2019-11-12T11:16:39.869607125Z'
```

Cloud Builds usually need code or data to work on to be useful.  This is specified by the `source` argument.  This can be a Cloud Source Repository (perhaps mirrored from GitHub) or a Cloud Storage bucket containg the code/data you want to operate on.  An example of specifying both is below:

```r
my_gcs_source <- Source(storageSource=StorageSource("gs://my-bucket", "my_code.tar.gz"))
my_repo_source <- Source(repoSource=RepoSource("https://my-repo.com", branchName="master"))

build1 <- cr_build("cloudbuild.yaml", source = my_gcs_source)
build2 <- cr_build("cloudbuild.yaml", source = my_repo_source)
```

You can also turn an existing build into a cloudbuild.yaml file:

```r
cr_build_write(build1)
```

### Schedule Cloud Build

As Cloud Build can run any code in a container, it becomes a powerful way to setup data flows.  These can be scheduled via Cloud Scheduler.  

A demo below shows how to set up a Cloud Build on a schedule from R:

```r
build1 <- cr_build_make("cloudbuild.yaml")

cr_schedule("15 5 * * *", name="cloud-build-test1",
             httpTarget = cr_build_schedule_http(build1))
```

We use `cr_build_make()` and `cr_build_schedule_http()` to create the Cloud Build API request, and then send that to the Cloud Scheduler API via its `httpTarget` parameter.

Cloud Scheduler can schedule HTTP requests to any endpoint:

```
cr_scheduler("14 5 * * *", name = "my-webhook", 
             httpTarget = HttpTarget(httpMethod="GET", uri = "https://mywebhook.com"))
```

### Build and schedule an R script

Putting the above together serverlessly, to schedue an R script the steps are:

1. Create your R script 
2. Bundle the R script with a Dockerfile
3. Build the Docker image on Cloud Build and push to "gcr.io/your-project/your-name"
4. Schedule calling the Docker image using Cloud Scheduler

#### 1. Create your R script

The R script can hold anything, but make sure its is self contained with auth files, data files etc.  All paths should be relative to the script.  Uploading auth files within Dockerfiles is not recommended security wise, but since the container is running on GCP you can use `googleAuthR::gar_gce_auth()` or similar to download configuration files from a GCE bucket in your script. 

#### 2. Bundle the R script with a Dockerfile

Creating your Dockerfile can be done using `containerit` - point it at the folder with your script:

```r
library(containerit)
d <- dockerfile("your-script.R")
write(d, "Dockerfile")
```

See its website for details.

#### 3. Build the Docker image on Cloud Build

Once you have your R script and Dockerfile in the same folder, you need to build the image.

*cloudbuild.yaml*

Lets say you don't want to write a cloudbuild.yaml file - instead its created all within R using the yaml helper functions `Yaml()` and `cr_build_step`.  Refer to the [cloudbuild.yaml config spec](https://cloud.google.com/cloud-build/docs/build-config) on what it expected in the file. 

```r
image <- "gcr.io/your-project/your-name"
my_yaml <- Yaml(
      steps = list(cr_build_step("docker", c("build","-t",image,".")),
                   cr_build_step("docker", c("push",image))),
      images = image)
my_yaml
# ==cloudRunnerYaml==
# steps:
# - name: gcr.io/cloud-builders/docker
#   args:
#   - build
#   - -t
#   - gcr.io/your-project/your-name
#   - '.'
#   dir: deploy
# - name: gcr.io/cloud-builders/docker
#   args:
#   - push
#   - gcr.io/your-project/your-name
#   dir: deploy
# images: gcr.io/your-project/your-name
```

You can also write out the yaml into your own cloudbuild.yaml

```r
cr_build_write(my_yaml, file = "cloudbuild.yaml")
```

This allows you to programmatically create cloudbuild yaml files.

*Source*

The code/source of the build also needs to be included.  This can be a Cloud Repository mirrored from GitHub, but here we will upload it to a folder on your own private Google Cloud Storage bucket.

This returns a `StorageSource` object which is needed for `Source`:

```
storage <- cr_build_upload_gcs("my_folder")
my_gcs_source <- Source(storageSource=storage)
```

You can now upload the build to Cloud Build, using your custom yaml and specifying the source of the data/code on the cloud storage bucket:

```
build <- cr_build(my_yaml, source = my_gcs_source)
```

Change and configure the Yaml or the source as you need.

#### 4. Schedule calling the Docker image using Cloud Scheduler

Once the image is build successfully, you do not need to build it again for the scheduled calls.  For that, you will only need the image you build ("gcr.io/your-project/your-name") and call it via the arguments set up in the Dockerfile i.e. "R -e my_r_script.R"

```
schedule_me <- Yaml(
  steps = list(
     cr_build_step("your-name", "R -e my_r_script.R", stem="gcr.io/your-project")
  )
)

schedule_build <- cr_build_make(schedule_me)

cr_schedule("15 5 * * *", name="scheduled_r",
             httpTarget = cr_build_schedule_http(schedule_build))

```

Your R script should now be scheduled and running in its own environment.

You can automate updates to the script and/or Docker container or schedule seperately, by redoing any of the steps above. 

## Cloud Run deployments

Cloud Run is a service that lets you deploy container images without worrying about the underlying servers or infrastructure.  It is called with the `cr_run()` function.

The Cloud Run API is not called directly when deploying - instead a Cloud Build is created for deployment. It creates a cloudbuild.yaml similar to the below:

```yaml
# use cloud build to deploy
image <- "gcr.io/my-project/my-image"
Yaml(
    steps = list(
      cr_build_step("docker", c("build","-t",image,".")),
      cr_build_step("docker", c("push",image)),
      cr_build_step("gcloud", c("beta","run","deploy", "my-name",
           "--image", image,
           "--region", "europe-west1",
           "--platform", "managed",
           "--concurrency", 1,
           "--allow-unauthenticated"
         ))
    ),
    images = image
  )
# ==cloudRunnerYaml==
# steps:
# - name: gcr.io/cloud-builders/docker
#   args:
#   - build
#   - -t
#   - gcr.io/my-project/my-image
#   - '.'
#   dir: deploy
# - name: gcr.io/cloud-builders/docker
#   args:
#   - push
#   - gcr.io/my-project/my-image
#   dir: deploy
# - name: gcr.io/cloud-builders/gcloud
#   args:
#   - beta
#   - run
#   - deploy
#   - my-name
#   - --image
#   - gcr.io/my-project/my-image
#   - --region
#   - europe-west1
#   - --platform
#   - managed
#   - --concurrency
#   - '1'
#   - --allow-unauthenticated
#   dir: deploy
# images: gcr.io/my-project/my-image

```

If you have an existing image you want to deploy on Cloud Run (usually one that serves up HTTP content, such as via `library(plumber)`) then you only need to supply that image to deploy:

```r
cr_run("gcr.io/my-project/my-image")
```

However, if you want to do the common use case of building the container first as well, you can do so by specifying a `Source` object containing the code, Dockerfile and data you want to build into the container:

```r
my_gcs_source <- Source(storageSource=StorageSource("gs://my-bucket", "my_code.tar.gz"))
build_run <- cr_run("gcr.io/my-project/my-image", source = my_gcs_source)
```

`cr_deploy()` wraps the above in functions to check and wait for status etc. and is intended as the main method of Cloud Run deployment, but you may want to tweak the settings more by calling `cr_run()` directly. 


## ToDo

Useful R specific cloudbuilds

* Checking a package, creating a website, deploying
* Creating an Rmarkdown powered website using Cloud Run


## Setup

### R Settings

* Reuses environment argument `GCE_AUTH_FILE` from googleComputeEngineR which holds location of your service auth JSON
* Reuses environment argument `GCE_DEFAULT_PROJECT_ID` from googleComputeEngineR
* Reuses environment argument `GCS_DEFAULT_BUCKET` from googleCloudStorageR
* New environment argument `CR_REGION` can be one of 

```
"us-central1",
"asia-northeast1",
"europe-west1",
"us-east1"
```
* New environment argument `CR_BUILD_EMAIL` that is your cloudbuild service email

e.g. your `.Renviron` should look like:

```
GCE_AUTH_FILE="/Users/me/auth/auth.json"
GCE_DEFAULT_PROJECT_ID="my-project"
GCS_DEFAULT_BUCKET="my-bucket"
CR_REGION="europe-west1"
CR_BUILD_EMAIL=my-project-number@cloudbuild.gserviceaccount.com
```

You can also set some of the above in the R script via:

* `cr_region_set()`
* `cr_project_set()`
* `cr_bucket_set()`

### GCP settings

* Ensure you have the Cloud Build, Cloud Run and CLoud Scheduler APIs on in your GCP project
* The Cloud Build service account needs permissions if you want it to deploy to Cloud Run: This can be set [here](https://console.cloud.google.com/cloud-build/settings) where you enable `Cloud Run Admin` and `Service Account User` roles.  More details found at this [Google reference article](https://cloud.google.com/cloud-build/docs/deploying-builds/deploy-cloud-run). 
* Ensure you have a service email with `service-{project-number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com` with Cloud Scheduler Service Agent role.  This only needs to exist in the GCP project, it is not used in deployment - create another service key for that. See [here](https://cloud.google.com/scheduler/docs/http-target-auth#add)
* A service auth key needs Cloud Build Editor, Cloud Run Admin, Cloud Scheduler Admin roles to use all the functions in the package - this key can be downloaded and used for auth via `GCE_AUTH_FILE`

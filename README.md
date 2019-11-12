# cloudRunner

[![Build Status](https://travis-ci.org/MarkEdmondson1234/cloudRunner.svg?branch=master)](https://travis-ci.org/MarkEdmondson1234/cloudRunner)
[![codecov](https://codecov.io/gh/MarkEdmondson1234/cloudRunner/branch/master/graph/badge.svg)](https://codecov.io/gh/MarkEdmondson1234/cloudRunner)

As easy as possible R scripts in the cloud, via Cloud Run...

## Ambition

Point your R code at a function, that automatically deploys and runs it in the cloud via an API endpoint...

## Usage

Set up auth, environment arguments etc. as per bottom of this file.

* R APIs

1. Make an R API via [plumber](https://www.rplumber.io/) that contains entry file api.R.  You can use the demo example in `inst/example` if you like.
2. Deploy via the `cr_deploy()` function:

```r
library(cloudRunner)

cr <- cr_deploy("api.R", remote = "my_r_api")
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

Deployment covers these steps:
1. Create a Dockerfile for your R script if necessary via [`containerit`](https://o2r.info/containerit/index.html)
2. Uploads the Dockerfile and your api.R file to your Google Cloud Storage bucket
3. Creates a Cloud Build job for building the files uploaded to the GCS bucket, and pushes the Docker images to Google Container Registry
3. Deploys that container to Cloud Run

It will launch a browser showing the build on Cloud Build, or you can wait for progress in your local R sesion.  Upon successfully deployment it gives you a `CloudRunService` object with details of the deployment. 

All the above stages can be customised for your own purposes.

* Run R builds

Cloud Run is only necessary if you want a URL endpoint for your script.  You can run other R scripts within Cloud Build that can be triggered one time for the R function, setup to trigger on GitHub events or pub/sub, or schedule the R scripts using Cloud Scheduler.

TODO: demo of running your own R script on Cloud Build/Scheduler

## Strategy

1. User wraps R code in generic plumber API endpoint
2. Get Dockerfile requirements via `containerit`
3. Push Dockerfile to build in Build Triggers - `cr_build()` (using cloudbuild.yaml)
4. Publish Docker image to Cloud Run - `cr_run()` via a cloud build calling gcloud
5. Return API endpoint
6. Schedule if necessary

You can also trigger cloud builds via scheduler, so no need for Cloud Run for non-public tasks. 

## Setup

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
* A service auth key needs Cloud Storage Admin, Cloud Run Admin, Cloud Scheduler Admin roles to use all the functions in the package - this key can be downloaded and used for auth via `GCE_AUTH_FILE`

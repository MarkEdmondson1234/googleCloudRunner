# cloudRunner

As easy as possible R scripts in the cloud, via Cloud Run

## Ambition

Point your R code at a function, that automatically deploys and runs it in the cloud via an API endpoint.

## Usage

```r
library(cloudRunner)

my_plumbed_file <- "api.R"

cr <- cr_deploy(my_plumbed_file)
# my_r_function available on https://cloud-run.hello-r.com

cr_schedule(cr, schedule = "1 5 * * *")
# my_r_function scheduled to run every day at 05:01
```

Also usable if you make your own Docker file or image

```
dock_file <- cr_dockerfile("Dockerfile")
cr_api_schedule(dock_file, schedule = "1 5 * * *")

dock_image <- cr_image("gcr.io/my-project/my-app")
cr_api_schedule(dock_image, schedule = "1 5 * * *")
```

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
CR_BUILD_EMAIL=demo@cloudbuild.gserviceaccount.com
```

You can also set in the R script via:

* `cr_region_set()`
* `cr_project_set()`
* `cr_bucket_set()`

### GCP settings

The Cloud Build service account needs permissions if you want it to deploy to Cloud Run.

This can be set [here](https://console.cloud.google.com/cloud-build/settings) where you enable `Cloud Run Admin` and `Service Account User` roles.  More details found at this [Google reference article](https://cloud.google.com/cloud-build/docs/deploying-builds/deploy-cloud-run). 

* https://cloud.google.com/scheduler/docs/http-target-auth#add Ensure you have a service email with service-{project-number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com with Cloud Scheduler Service Agent role. 

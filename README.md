# cloudRunner

As easy as possible R scripts in the cloud, via Cloud Run

## Ambition

Point your R code at a function, that automatically deploys and runs it in the cloud via an API endpoint.

## Usage

```r
library(cloudRunner)

my_plumbed_file <- "api.R"

cr <- cr_plumber(my_plumbed_file)
# my_r_function available on https://cloud-run.hello-r.com

cr_api_schedule(cr, schedule = "1 5 * * *")
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
3. Push Dockerfile to build in Build Triggers
4. Publish Docker image to Cloud Run
5. Return API endpoint
6. Schedule if necessary

Can a standard Cloud Run be used to build other images?

## Setup

`CR_ENDPOINTS` must be one of 

```
"us-central1",
"asia-northeast1",
"europe-west1",
"us-east1"
```

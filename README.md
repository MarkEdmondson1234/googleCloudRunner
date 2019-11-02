# cloudRunner

As easy as possible R scripts in the cloud, via Cloud Run

## Ambition

Point your R code at a function, that automatically deploys and runs it in the cloud via an API endpoint.

## Usage

```r
library(cloudRunner)


cr <- cr_api(my_r_function)
# my_r_function available on https://cloud-run.hello-r.com

cr_api_schedule(cr, schedule = "1 5 * * *")
# my_r_function scheduled to run every day at 05:01
```

## Strategy

1. Wrap R code in generic plumber API endpoint
2. Get Dockerfile requirements via `containerit`
3. Push Dockerfile to build in Build Triggers
4. Publish Docker image to Cloud Run
5. Return API endpoint
6. Schedule if necessary


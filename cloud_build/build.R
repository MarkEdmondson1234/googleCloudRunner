library(googleCloudRunner)


docker_steps <- cr_build_yaml(
  c(cr_buildstep_gcloud(
    args = c("gcloud run regions list > regions.txt"),
    dir = "data-raw"
  ),
  cr_buildstep_r(
    "data-raw/cloudrun-regions.R",
    name = "tidyverse",
    r_source = "runtime"
  ),
  cr_buildstep_docker("gcr.io/gcer-public/googlecloudrunner",
                      tag = c("latest","$BRANCH_NAME"),
                      dockerfile = "cloud_build/Dockerfile",
                      kaniko_cache = TRUE))
)

cr_build_write(docker_steps, file = "cloud_build/cloudbuild.yml")

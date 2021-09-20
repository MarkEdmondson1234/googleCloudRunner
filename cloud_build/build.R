library(googleCloudRunner)


docker_steps <- cr_build_yaml(
  c(cr_buildstep_gcloud(
    args = c(
      "bash",
      "-c",
      "ls -al && gcloud run regions list > data-raw/regions.txt"),
  ),
  cr_buildstep_r(
    "data-raw/cloudrun-regions.R",
    name = "tidyverse",
    r_source = "runtime"
  ),
  cr_buildstep_docker("gcr.io/gcer-public/googlecloudrunner",
                      tag = c("latest","$BRANCH_NAME"),
                      dockerfile = "cloud_build/Dockerfile",
                      kaniko_cache = TRUE)
  )
)

cr_build_write(docker_steps, file = "cloud_build/cloudbuild.yml")

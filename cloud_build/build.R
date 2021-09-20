library(googleCloudRunner)


docker_steps <- cr_build_yaml(
  cr_buildstep_docker("gcr.io/gcer-public/googlecloudrunner",
                      tag = c("latest","$BRANCH_NAME"),
                      dockerfile = "cloud_build/Dockerfile",
                      kaniko_cache = TRUE)
  )

cr_build_write(docker_steps, file = "cloud_build/cloudbuild.yml")

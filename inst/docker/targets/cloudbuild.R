# script to generate cloudbuild.yaml and build the Docker
library(googleCloudRunner)

repo <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner", branch = "master")

# creates gcr.io/gcer-public/targets docker image with renv and targets
cr_deploy_docker_trigger(
  repo = repo,
  image = "targets",
  projectId_target = "gcer-public",
  dir = "inst/docker/targets/"
)

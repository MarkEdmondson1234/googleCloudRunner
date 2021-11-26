library(googleCloudRunner)

# put parsing DESCRIPTION here

# add to Dockerfile


# build on trigger
cr_buildtrigger_delete(paste0("docker-gcr-io-gcer-",
                              "public-github-codespace-googlecloudrunner"))
cr_deploy_docker_trigger(
  cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner"),
  image = "gcr.io/gcer-public/github-codespace/googlecloudrunner",
  location = "inst/docker/github",
  includedFiles = c(".devcontainer/**", "inst/docker/github/**"),
  timeout = 2400
)

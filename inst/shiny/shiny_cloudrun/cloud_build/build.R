library(googleCloudRunner)

repo <- cr_buildtrigger_repo("MarkEdmondson1234/shiny-cloudrun-demo")
cr_deploy_docker_trigger(
  repo,
  image = "shiny-cloudrun"
)

cr_run(sprintf("gcr.io/%s/shiny-cloudrun:latest",cr_project_get()),
       name = "shiny-cloudrun",
       concurrency = 10,
       max_instances = 1)

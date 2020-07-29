library(googleCloudRunner)

# deploy the app version from this folder
cr_deploy_run("inst/shiny/image_talker/app/",
              remote = "image_talker",
              tag = c("latest","$BUILD_ID"),
              max_instances = 1,
              concurrency = 80)


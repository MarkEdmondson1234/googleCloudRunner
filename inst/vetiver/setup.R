library(parsnip)
library(workflows)
data(Sacramento, package = "modeldata")

rf_spec <- rand_forest(mode = "regression")
rf_form <- price ~ type + sqft + beds + baths

rf_fit <-
  workflow(rf_form, rf_spec) %>%
  fit(Sacramento)

library(vetiver)
v <- vetiver_model(rf_fit, "sacramento_rf")

root <- file.path("inst","vetiver")

library(pins)
model_board <- board_folder(file.path(root,"plumber/pins"))
model_board %>% vetiver_pin_write(v)

library(googleCloudRunner)

# the docker takes a long time to install arrow so build it first to cache
repo <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner")

cr_deploy_docker_trigger(repo, "vetiver",
                         location = "inst/vetiver/docker/",
                         includedFiles = "inst/vetiver/**",
                         projectId_target = "gcer-public")

cr_deploy_plumber(file.path(root,"plumber"), timeout = 3600)

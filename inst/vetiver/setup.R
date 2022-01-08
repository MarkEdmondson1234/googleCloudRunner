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
repo <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner",
                             branch = "vetiver")

#cr_buildtrigger_delete("docker-vetiver")
cr_deploy_docker_trigger(repo, "vetiver",
                         location = "inst/vetiver/docker/",
                         includedFiles = "inst/vetiver/**",
                         projectId_target = "gcer-public",
                         timeout = 3600)

run <- cr_deploy_plumber(file.path(root,"plumber"), remote = "vetiver")

# on succesful deployment
endpoint <- vetiver::vetiver_endpoint(paste0(jj$status$url, "/predict"))
library(tidyverse)
data(Sacramento, package = "modeldata")
new_sac <- Sacramento %>%
  slice_sample(n = 20) %>%
  select(type, sqft, beds, baths)



library(googleCloudRunner)

bs <- c(
  cr_buildstep_secret("mark-edmondson-gde-auth",
      decrypted = "inst/docker/parallel_cloudrun/plumber/auth.json"),
  cr_buildstep_docker("cloudrun_parallel",
                      dir = "inst/docker/parallel_cloudrun/plumber",
                      kaniko_cache = TRUE),
  cr_buildstep_run("parallel-cloudrun",
                   image = "gcr.io/$PROJECT_ID/cloudrun_parallel:$BUILD_ID",
                   allowUnauthenticated = FALSE,
                   env_vars = "BQ_AUTH_FILE=auth.json")
)

by <- cr_build_yaml(bs)
cr_build_write(by, file = "cloudbuild.yml")

repo <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner")
cr_buildtrigger("inst/docker/parallel_cloudrun/cloudbuild.yml",
                "parallel-cloudrun",
                trigger = repo,
                includedFiles = "inst/docker/parallel_cloudrun/**")

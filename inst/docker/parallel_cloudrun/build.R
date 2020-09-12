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

cr <- cr_run_get("parallel-cloudrun")
options(googleAuthR.verbose = 1)
# its an authenticated call only API, so we need an auth token.
# curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" https://parallel-cloudrun-ewjogewawq-ew.a.run.app/hello

library(jose)

aj <- jsonlite::fromJSON(Sys.getenv("GCE_AUTH_FILE"))

claim <- jwt_claim(
  target_audience = "https://parallel-cloudrun-ewjogewawq-ew.a.run.app",
  azp = aj$client_id,
  email = aj$client_email,
  email_verified = TRUE,
  exp = unclass(Sys.time()+3600),
  iss = "https://accounts.google.com",
  sub = aj$client_id
)

encode <- jwt_encode_sig(claim, aj$private_key)

httr::POST(aj$token_uri, body = encode)



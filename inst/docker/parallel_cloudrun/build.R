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
                   env_vars = "BQ_AUTH_FILE=auth.json,BQ_DEFAULT_PROJECT_ID=$PROJECT_ID")
)

by <- cr_build_yaml(bs)
cr_build_write(by, file = "inst/docker/parallel_cloudrun/cloudbuild.yml")

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

create_signed_jwt <- function(the_url,
                              service_json = Sys.getenv("GCE_AUTH_FILE"),
                              scope=NULL){

  aj <- jsonlite::fromJSON(service_json)
  headers <- list(
    'kid' = aj$private_key_id,
    "alg" = "RS256",
    "typ" = "JWT"	# Google uses SHA256withRSA
  )

  claim <- jose::jwt_claim(
    target_audience = the_url,
    aud = 'https://www.googleapis.com/oauth2/v4/token',
    exp = unclass(Sys.time()+3600),
    iss = aj$client_email,
    sub = aj$client_email,
    scope = scope
  )

  jose::jwt_encode_sig(claim,
                 key = aj$private_key,
                 header = headers)
}

exchangeJwtForAccessToken <- function(signed_jwt, the_url){
  auth_url = "https://www.googleapis.com/oauth2/v4/token"

  params = list(
    grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion = signed_jwt
  )

  res <- httr::POST(auth_url, body = params)

  httr::content(res)$id_token
}

add_jwt <- function(req, jwt){
  res <- with_config(
    config = httr::add_headers(
      Authorization = sprintf("Bearer %s", jwt)
    ),
    req
  )

  httr::content(res)

}

the_url <- "https://parallel-cloudrun-ewjogewawq-ew.a.run.app/"
jwt <- create_signed_jwt(the_url)

token <- exchangeJwtForAccessToken(jwt, the_url)

# call Cloud Run with token!
add_jwt(httr::GET("https://parallel-cloudrun-ewjogewawq-ew.a.run.app/hello"), token)




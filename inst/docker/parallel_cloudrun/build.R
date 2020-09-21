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

# make a buildtrigger pointing at above steps
cloudbuild_file <- "inst/docker/parallel_cloudrun/cloudbuild.yml"
by <- cr_build_yaml(bs)
cr_build_write(by, file = cloudbuild_file)

repo <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner")
cr_buildtrigger(cloudbuild_file,
                "parallel-cloudrun",
                trigger = repo,
                includedFiles = "inst/docker/parallel_cloudrun/**")

cr <- cr_run_get("parallel-cloudrun")

# Interact with the authenticated Cloud Run service
the_url <- cr$status$url
jwt <- cr_jwt_create(the_url)

# needs to be recreated every 60mins
token <- cr_jwt_token(jwt, the_url)

# call Cloud Run with token!
library(httr)
res <- cr_jwt_with_httr(GET("https://parallel-cloudrun-ewjogewawq-ew.a.run.app/hello"),
                   token)
content(res)

# interact with the API we made
call_api <- function(region, industry, token){
  api <- sprintf("https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=%s&industry=%s",
                 URLencode(region), URLencode(industry))

  message("Request: ", api)
  res <- cr_jwt_with_httr(httr::GET(api),token)

  httr::content(res, as = "text", encoding = "UTF-8")

}

# test call
result <- call_api(region = "Europe", industry = "Software", token = token)

# the variables to loop over
regions <- c("North America", "Europe","South America","Australia")
industry <- c("Transportation (non-freight)",
              "Software",
              "Telecommunications",
              "Manufacturing",
              "Real Estate",
              "Government",
              "Construction",
              "Holding Companies & Conglomerates",
              "Freight & Logistics Services",
              "Agriculture",
              "Retail",
              "Consumer Services",
              "Hospitality",
              "Business Services",
              "Waste Treatment, Environmental Services & Recycling",
              "Energy & Utilities",
              "Education",
              "Insurance",
              "Media & Internet",
              "Minerals & Mining",
              "Healthcare Services & Hospitals",
              "Organizations",
              "Finance")

# loop over all variables for parallel processing
library(future.apply)

# not multisession to avoid https://github.com/HenrikBengtsson/future.apply/issues/4
plan(multicore)

results <- future_lapply(regions, call_api, industry = "Software", token = token)

# loop over all industries and regions
all_results <- lapply(regions, function(x){

  future_lapply(industry, function(y){
    call_api(region = x, industry = y, token = token)
  })

})

## curl multi asynch
# interact with the API we made
make_urls <- function(regions, industry){

  combos <- expand.grid(regions, industry, stringsAsFactors = FALSE)

  unlist(mapply(function(x,y){sprintf("https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=%s&industry=%s",URLencode(x), URLencode(y))},
                SIMPLIFY = FALSE, USE.NAMES = FALSE,
         combos$Var1 ,combos$Var2))
}

all_urls <- make_urls(regions = regions, industry = industry)

cr_jwt_async(all_urls[1:5], token = token)

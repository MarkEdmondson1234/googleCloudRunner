#' Set the endpoint for your CloudRun services
#'
#' @param region Region for the endpoint
#' @import assertthat
#' @export
cr_region_set <- function(region = c("europe-west1",
                               "us-central1",
                               "asia-northeast1",
                               "us-east1")){

  region <- match.arg(region)

  .cr_env$region <- region

  myMessage("Region set to ", .cr_env$region, level = 3)
  .cr_env$region
}

#' @export
cr_region_get <- function(){
  if(Sys.getenv("CR_REGION") != ""){
    .cr_env$region <- Sys.getenv("CR_REGION")
  }
  if(is.null(.cr_env$region)){
    stop("No region set - use cr_region_set()")
  }
  .cr_env$region
}

ENDPOINTS <- c("us-central1",
               "asia-northeast1",
               "europe-west1",
               "us-east1")


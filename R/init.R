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
  if(is.null(.cr_env$region)){
    stop("No region set - use cr_region_set()")
  }
  .cr_env$region
}

ENDPOINTS <- c("us-central1",
               "asia-northeast1",
               "europe-west1",
               "us-east1")

make_endpoint <- function(parent){
  region <- .cr_env$region

  if(is.null(region)){
    region <- Sys.getenv("CRUN_ENDPOINT")
  }

  if(is.null(region)){
    stop("Must select region via cr_region_set() or set environment CRUN_ENDPOINT",
         call. = FALSE)
  }

  if(!region %in% ENDPOINTS){
    warning("Endpoint is not one of ", paste(ENDPOINTS, collapse = " "), " got: ", region)
  }

  sprintf("https://%s-run.googleapis.com/apis/serving.knative.dev/v1/namespaces/%s/services",
          region, parent)
}
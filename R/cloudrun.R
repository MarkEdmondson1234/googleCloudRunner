ENDPOINTS <- c("us-central1",
               "asia-northeast1",
               "europe-west1",
               "us-east1")

make_endpoint <- function(parent){
  endpoint <- .cr_env$endpoint

  if(is.null(endpoint)){
    endpoint <- Sys.getenv("CRUN_ENDPOINT")
  }

  if(is.null(endpoint)){
    stop("Must select endpoint via cr_endpoint_set() or set environment CRUN_ENDPOINT", call. = FALSE)
  }

  if(!endpoint %in% ENDPOINTS){
    warning("Endpoint is not one of ", paste(ENDPOINTS, collapse = " "), " got: ", endpoint)
  }

  sprintf("https://%s-run.googleapis.com/apis/serving.knative.dev/v1/namespaces/%s/services",
          endpoint, parent)
}

#' Set the endpoint for your CloudRun services
#'
#' @param region Region for the endpoint
#' @param override Set a full endpoint starting with https here if necessary
#' @import assertthat
#' @export
cr_endpoint_set <- function(region = c("us-central1",
                                       "asia-northeast1",
                                       "europe-west1",
                                       "us-east1"),
                            override = NULL){

  region <- match.arg(region)

  if(!is.null(override)){
    .cr_env$endpoint <- override
    return(override)
  }

  .cr_env$endpoint <- sprintf("https://%s-run.googleapis.com", region)

  myMessage("Endpoint set to ", .cr_env$endpoint, level = 3)
  .cr_env$endpoint
}


#' Create a CloudRun service
#' @export
cr_run <- function(){
  NULL
}

#' List CloudRun services.
#'
#'
#' @seealso \href{https://cloud.google.com/run/}{Google Documentation}
#'
#' @details
#'
#' @param parent The GCP project from which the services should be listed
#' @param labelSelector Allows to filter resources based on a label
#' @param limit The maximum number of records that should be returned
#' @importFrom googleAuthR gar_api_generator
#' @export
cr_run_list <- function(project,
                            labelSelector = NULL,
                            limit = NULL) {

  url <- make_endpoint(project)
  # run.namespaces.services.list
  #TODO: paging
  pars = list(labelSelector = labelSelector, continue = NULL, limit = limit)
  f <- gar_api_generator(url,
                         "GET",
                         pars_args = rmNullObs(pars),
                         data_parse_function = parse_service_list)
  f()

}

#' @noRd
#' @import assertthat
parse_service_list <- function(x){
  assert_that(
    x$kind == "ServiceList"
  )

  structure(
    x$items,
    class = c(x$kind, "data.frame"))

}



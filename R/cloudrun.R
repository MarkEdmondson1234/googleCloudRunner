#' Create a CloudRun service.
#'
#' Deploys an existing gcr.io image.
#'
#' @seealso \href{https://cloud.google.com/run/}{Google Documentation for Cloud Run}
#' @seealso Use \link{cr_deploy_docker} or similar to create image, \link{cr_deploy_run} to automate building and deploying, \link{cr_deploy_plumber} to deploy plumber APIs.
#'
#' @param image The name of the image to create or use in deployment - \code{gcr.io}
#' @param name Name for deployment on Cloud Run
#' @param concurrency How many connections each image can serve. Can be up to 80.
#' @param port Container port to receive requests at. Also sets the $PORT environment variable. Must be a number between 1 and 65535, inclusive. To unset this field, pass the special value "default".
#' @param region The endpoint region for deployment
#' @param projectId The GCP project from which the services should be listed
#' @param allowUnauthenticated TRUE if can be reached from public HTTP address.
#'
#' @inheritParams cr_build
#' @importFrom googleAuthR gar_api_generator
#' @family Cloud Run functions
#'
#' @details
#'
#'  Uses Cloud Build to deploy an image to Cloud Run
#'
#' @seealso \href{https://cloud.google.com/cloud-build/docs/deploying-builds/deploy-cloud-run}{Deploying Cloud Run using Cloud Build}
#'
#' @export
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_run("gcr.io/my-project/my-image")
#' }
cr_run <- function(image,
                   name = basename(image),
                   allowUnauthenticated = TRUE,
                   concurrency = 1,
                   port = NULL,
                   timeout=600L,
                   region = cr_region_get(),
                   projectId = cr_project_get(),
                   launch_browser=interactive()) {

  myMessage(paste("#> Launching CloudRun image: ",image),
            level = 3)

  # use cloud build to deploy
  run_yaml <- cr_build_yaml(
    steps = cr_buildstep_run(name = name,
                             image = image,
                             allowUnauthenticated = allowUnauthenticated,
                             region = region,
                             concurrency = concurrency,
                             port = port)
  )

  build <- cr_build(run_yaml,
                    projectId=projectId,
                    timeout = timeout,
                    launch_browser=launch_browser)

  result <- cr_build_wait(build, projectId = projectId)

  if(result$status == "SUCCESS"){
    run <- cr_run_get(name, projectId = projectId)
    myMessage(paste("#> Running at: ",
                     run$status$url), level = 3)

    if(launch_browser) utils::browseURL(run$status$url)

    return(run)
  } else {
    myMessage("#Problem deploying to Cloud Run", level = 3)
    return(result)
  }
}



make_endpoint <- function(endbit){
  region <- .cr_env$region

  if(is.null(region)){
    region <- Sys.getenv("CR_REGION")
    .cr_env$region <- region
  }

  if(is.null(region) || region == ""){
    stop("Must select region via cr_region_set() or set environment CR_REGION",
         call. = FALSE)
  }

  endpoints <- c("us-central1",
                 "asia-northeast1",
                 "europe-west1",
                 "us-east1")
  if(!region %in% endpoints){
    warning("Endpoint is not one of ",
            paste(endpoints, collapse = " "), " got: ", region)
  }

  sprintf("https://%s-run.googleapis.com/apis/serving.knative.dev/v1/%s",
          region, endbit)
}


#' List CloudRun services.
#'
#' List the Cloud Run services you have access to
#'
#' @seealso \href{https://cloud.run}{Google Documentation for Cloud Run}
#'
#' @param projectId The GCP project from which the services should be listed
#' @param labelSelector Allows to filter resources based on a label
#' @param limit The maximum number of records that should be returned
#' @param summary If TRUE will return only a subset of info available, set to FALSE for all metadata
#' @importFrom googleAuthR gar_api_generator
#' @family Cloud Run functions
#' @export
cr_run_list <- function(projectId = cr_project_get(),
                        labelSelector = NULL,
                        limit = NULL,
                        summary = TRUE) {

  assert_that(
    is.flag(summary)
  )

  url <- make_endpoint(sprintf("namespaces/%s/services", projectId))
  myMessage("Cloud Run services in region: ",
            .cr_env$region, level = 3)
  # run.namespaces.services.list
  #TODO: paging
  pars <-  list(labelSelector = labelSelector,
                continue = NULL,
                limit = limit)
  f <- gar_api_generator(url,
                         "GET",
                         pars_args = rmNullObs(pars),
                         data_parse_function = parse_service_list,
                         checkTrailingSlash=FALSE)
  o <- f()

  if(!summary){
    return(o)
  }

  parse_service_list_post(o)

}

#' @noRd
#' @import assertthat
parse_service_list <- function(x){
  assert_that(
    x$kind == "ServiceList"
  )

  x$items

}

parse_service_list_post <- function(x){

  data.frame(
    name = x$metadata$name,
    container = unlist(lapply(x$spec$template$spec$containers,
                              function(x) x$image)),
    url = x$status$url,
    stringsAsFactors = FALSE
  )

}

#' Get information about a Cloud Run service.
#'
#'
#' @seealso \href{https://cloud.google.com/run/docs/reference/rest/v1/namespaces.services/get}{Google Documentation on namespaces.services.get}
#'
#' @details This returns details on a particular deployed Cloud Run service.
#'
#' @param name The name of the service to retrieve
#' @param projectId The projectId to get from
#'
#' @importFrom googleAuthR gar_api_generator
#' @family Cloud Run functions
#' @export
cr_run_get <- function(name, projectId = cr_project_get()) {

  url <- make_endpoint(sprintf("namespaces/%s/services/%s",
                               projectId, name))

  # run.namespaces.services.get
  f <- gar_api_generator(url, "GET",
                         data_parse_function = parse_service_get,
                         checkTrailingSlash = FALSE)
  f()

}

#' @import assertthat
#' @noRd
parse_service_get <- function(x){
  assert_that(
    x$kind == "Service"
  )

  structure(
    x,
    class = c("gar_Service", "list")
  )
}

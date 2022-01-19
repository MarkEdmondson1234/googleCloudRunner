#' Create a CloudRun service.
#'
#' Deploys an existing gcr.io image.
#'
#' @seealso \href{https://cloud.google.com/run/}{Google Documentation for Cloud Run}
#' @seealso Use \link{cr_deploy_docker} or similar to create image, \link{cr_deploy_run} to automate building and deploying, \link{cr_deploy_plumber} to deploy plumber APIs.
#'
#' @param image The name of the image to create or use in deployment - \code{gcr.io}
#' @param name Name for deployment on Cloud Run
#' @param concurrency How many connections each container instance can serve. Can be up to 80.
#' @param port Container port to receive requests at. Also sets the $PORT environment variable. Must be a number between 1 and 65535, inclusive. To unset this field, pass the special value "default".
#' @param region The endpoint region for deployment
#' @param projectId The GCP project from which the services should be listed
#' @param allowUnauthenticated TRUE if can be reached from public HTTP address. If FALSE will configure a service-email called \code{(name)-cloudrun-invoker@(project-id).iam.gserviceaccount.com}
#' @param max_instances the desired maximum nuimber of container instances. "default" is 1000, you can get more if you requested a quota instance.  For Shiny instances on Cloud Run, this needs to be 1.
#' @param memory The format for size is a fixed or floating point number followed by a unit: G, M, or K corresponding to gigabyte, megabyte, or kilobyte, respectively, or use the power-of-two equivalents: Gi, Mi, Ki corresponding to gibibyte, mebibyte or kibibyte respectively. The default is 256Mi
#' @param cpu 1 or 2 CPUs for your instance
#' @param env_vars Environment arguments passed to the Cloud Run container at runtime.  Distinct from \code{env} that run at build time.
#' @param gcloud_args a character string of arguments that can be sent to the gcloud command not covered by other parameters of this function
#' @param ... Other arguments passed to \link{cr_buildstep_run}
#' @inheritDotParams cr_buildstep_run
#'
#' @inheritParams cr_build
#' @importFrom googleAuthR gar_api_generator
#' @family Cloud Run functions
#'
#' @details
#'
#'  Uses Cloud Build to deploy an image to Cloud Run
#'
#' @seealso \href{https://cloud.google.com/build/docs/deploying-builds/deploy-cloud-run}{Deploying Cloud Run using Cloud Build}
#'
#' @export
#' @examples
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_run("gcr.io/my-project/my-image")
#' cr_run("gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable",
#'   env_vars = c("CONTAINER_CONFIG=xxxxxxx")
#' )
#' }
cr_run <- function(image,
                   name = basename(image),
                   allowUnauthenticated = TRUE,
                   concurrency = 1,
                   port = NULL,
                   max_instances = "default",
                   memory = "256Mi",
                   cpu = 1,
                   timeout = 600L,
                   region = cr_region_get(),
                   projectId = cr_project_get(),
                   launch_browser = interactive(),
                   env_vars = NULL,
                   gcloud_args = NULL,
                   ...) {
  myMessage(paste("#> Launching CloudRun image: ", image),
    level = 3
  )

  assert_that(
    is.string(image),
    is.string(name),
    is.flag(allowUnauthenticated)
  )

  # use cloud build to deploy
  run_yaml <- cr_build_yaml(
    steps = c(
      add_docker_auth_prestep(image = image, pre_steps = NULL),
      cr_buildstep_run(
        name = name,
        image = image,
        allowUnauthenticated = allowUnauthenticated,
        region = region,
        concurrency = concurrency,
        port = port,
        max_instances = max_instances,
        memory = memory,
        cpu = cpu,
        env_vars = env_vars,
        gcloud_args = gcloud_args,
        ...
      )
    )
  )

  build <- cr_build(run_yaml,
    projectId = projectId,
    timeout = timeout,
    launch_browser = launch_browser
  )

  result <- cr_build_wait(build, projectId = projectId)

  if (result$status == "SUCCESS") {
    run <- cr_run_get(name, projectId = projectId)
    myMessage(paste(
      "#> Running at: ",
      run$status$url
    ), level = 3)

    if (launch_browser) utils::browseURL(run$status$url)

    return(run)
  } else {
    myMessage("#Problem deploying to Cloud Run", level = 3)
    return(result)
  }
}



make_endpoint <- function(endbit) {
  region <- .cr_env$region

  if (is.null(region)) {
    region <- Sys.getenv("CR_REGION")
    .cr_env$region <- region
  }

  if (is.null(region) || region == "") {
    stop("Must select region via cr_region_set() or set environment CR_REGION",
      call. = FALSE
    )
  }

  endpoints <- c(
    "us-central1",
    "asia-northeast1",
    "europe-west1",
    "us-east1"
  )
  if (!region %in% endpoints) {
    warning(
      "Endpoint is not one of ",
      paste(endpoints, collapse = " "), " got: ", region
    )
  }

  sprintf(
    "https://%s-run.googleapis.com/apis/serving.knative.dev/v1/%s",
    region, endbit
  )
}


#' List CloudRun services.
#'
#' List the Cloud Run services you have access to
#'
#' @seealso \href{https://cloud.google.com/run/}{Google Documentation for Cloud Run}
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
    .cr_env$region,
    level = 3
  )
  # run.namespaces.services.list
  # TODO: paging
  pars <- list(
    labelSelector = labelSelector,
    continue = NULL,
    limit = limit
  )
  f <- gar_api_generator(url,
    "GET",
    pars_args = rmNullObs(pars),
    data_parse_function = parse_service_list,
    checkTrailingSlash = FALSE
  )
  o <- f()

  if (!summary) {
    return(o)
  }

  parse_service_list_post(o)
}

#' @noRd
#' @import assertthat
parse_service_list <- function(x) {
  assert_that(
    x$kind == "ServiceList"
  )

  x$items
}

parse_service_list_post <- function(x) {
  data.frame(
    name = x$metadata$name,
    container = unlist(lapply(
      x$spec$template$spec$containers,
      function(x) x$image
    )),
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
  url <- make_endpoint(sprintf(
    "namespaces/%s/services/%s",
    projectId, name
  ))

  # run.namespaces.services.get
  f <- gar_api_generator(url, "GET",
    data_parse_function = parse_service_get,
    checkTrailingSlash = FALSE
  )

  err_404 <- sprintf("Cloud Run: %s in project %s not found",
                     name, projectId)

  handle_errs(f, http_404 = cli::cli_alert_danger(err_404))

}

#' @import assertthat
#' @noRd
parse_service_get <- function(x) {
  assert_that(
    x$kind == "Service"
  )

  structure(
    x,
    class = c("gar_Service", "list")
  )
}

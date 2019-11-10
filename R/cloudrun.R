#' Create a CloudRun service.
#'
#' @seealso \href{https://cloud.google.com/run/}{Google Documentation for Cloud Run}
#'
#' @inheritParams ObjectMeta
#' @inheritParams RevisionSpec
#' @inheritParams Container
#' @param projectId The GCP project from which the services should be listed
#' @param allowUnauthenticated TRUE if can be reached from public HTTP address.
#' @importFrom googleAuthR gar_api_generator
#' @family Service functions
#'
#' @details
#'
#'  Uses Cloud Build to deploy an image to Cloud Run
#'  https://cloud.google.com/cloud-build/docs/deploying-builds/deploy-cloud-run
#'
#' @export
#' @examples
#'
#' \dontrun{
#' cr_region_set("europe-west1")
#' cr_run("gcr.io/my-project/my-image")
#'
#' }
cr_run <- function(image,
                   source = NULL,
                   region = cr_region_get(),
                   name = basename(image),
                   allowUnauthenticated = TRUE,
                   concurrency = 1,
                   projectId = Sys.getenv("GCE_DEFAULT_PROJECT_ID")) {

  if(!is.null(source)){
    assert_that(is.gar_Source(source))
    source_build_steps <- list(
      cr_build_step("docker", c("build","-t",image,".")),
      cr_build_step("docker", c("push",image))
    )
  } else {
    myMessage("No source specified, deploying existing container ", image, level =3)
    source_build_steps <- NULL
  }

  # use cloud build to deploy
  run_yaml <- Yaml(
    steps = list(
      cr_build_step("ubuntu", "ls", ""),
      source_build_steps,
      cr_build_step("gcloud",
         c("beta","run","deploy", name,
           "--image", image,
           "--region", region,
           "--platform", "managed",
           "--concurrency", concurrency,
           if(allowUnauthenticated) "--allow-unauthenticated" else "--no-allow-unauthenticated"
         ))
    ),
    images = image
  )

  cr_build(run_yaml,
           source = source,
           images = image,
           projectId=projectId)

}

#' Create a yaml build step
#' @param name name of SDK appended to stem
#' @param args character vector of arguments
#' @param stem prefixed to name
#' @export
cr_build_step <- function(name, args, stem = "gcr.io/cloud-builders/"){
  list(
    name = paste0(stem, name),
    args = args
  )
}


#' List CloudRun services.
#'
#'
#' @seealso \href{https://cloud.run}{Google Documentation for Cloud Run}
#'
#' @details
#'
#' @param projectId The GCP project from which the services should be listed
#' @param labelSelector Allows to filter resources based on a label
#' @param limit The maximum number of records that should be returned
#' @importFrom googleAuthR gar_api_generator
#' @export
cr_run_list <- function(projectId = Sys.getenv("GCE_DEFAULT_PROJECT_ID"),
                        labelSelector = NULL,
                        limit = NULL) {

  url <- make_endpoint(projectId)
  # run.namespaces.services.list
  #TODO: paging
  pars = list(labelSelector = labelSelector, continue = NULL, limit = limit)
  f <- gar_api_generator(url,
                         "GET",
                         pars = rmNullObs(pars),
                         data_parse_function = parse_service_list,
                         checkTrailingSlash=FALSE)
  f()

}

#' @noRd
#' @import assertthat
parse_service_list <- function(x){
  assert_that(
    x$kind == "ServiceList"
  )

  x$items

}

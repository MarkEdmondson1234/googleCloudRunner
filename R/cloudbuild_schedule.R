#' Create a Cloud Scheduler HTTP target from a Cloud Build object
#'
#' This enables Cloud Scheduler to trigger Cloud Builds
#'
#' @seealso https://cloud.google.com/cloud-build/docs/api/reference/rest/v1/projects.builds/create
#'
#' @param build A \link{Build} object
#' @param projectId The projectId
#'
#' @return A \link{HttpTarget} object for use in \link{cr_schedule}
#'
#' @export
#' @import assertthat
#' @importFrom jsonlite toJSON
#' @importFrom openssl base64_encode
#' @family Cloud Scheduler functions, Cloud Build functions
cr_build_schedule_http <- function(build, projectId = cr_project_get()){

  assert_that(
    is.gar_Build(build)
  )
  HttpTarget(
    httpMethod = "POST",
    uri = sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/builds",
                  projectId),
    body = base64_encode(toJSON(build, auto_unbox = TRUE),linebreaks = FALSE),
   # oauthToken = list(serviceAccountEmail = get_service_email())
   oauthToken = NULL
  )
}


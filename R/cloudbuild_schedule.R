#' Create a Cloud Scheduler HTTP target from a Cloud Build object
#'
#' This enables Cloud Scheduler to trigger Cloud Builds
#'
#' @seealso https://cloud.google.com/cloud-build/docs/api/reference/rest/v1/projects.builds/create
#'
#' @param build A \link{Build} object usually created with \link{cr_build_make}
#' @param projectId The projectId
#'
#' @return A \link{HttpTarget} object for use in \link{cr_schedule}
#'
#' @details Ensure you have a service email with \link{cr_email_set} of format \code{service-{project-number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com} with Cloud Scheduler Service Agent role as per https://cloud.google.com/scheduler/docs/http-target-auth#add
#'
#' @export
#' @import assertthat
#' @family Cloud Scheduler functions, Cloud Build functions
#'
#' @examples
#'
#' build1 <- cr_build_make("inst/cloudbuild/cloudbuild.yaml")
#' build1
#' \dontrun{
#' cr_schedule("15 5 * * *", name="cloud-build-test1",
#'             httpTarget = cr_build_schedule_http(build1))
#' }
#'
cr_build_schedule_http <- function(build, projectId = cr_project_get()){

  assert_that(
    is.gar_Build(build)
  )
  HttpTarget(
    httpMethod = "POST",
    uri = sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/builds",
                  projectId),
    body = build,
    oauthToken = list(serviceAccountEmail = get_service_email())
  )
}


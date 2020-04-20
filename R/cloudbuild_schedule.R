#' Create a Cloud Scheduler HTTP target from a Cloud Build object
#'
#' This enables Cloud Scheduler to trigger Cloud Builds
#'
#' @seealso https://cloud.google.com/cloud-build/docs/api/reference/rest/v1/projects.builds/create
#'
#' @param build A \link{Build} object created via \link{cr_build_make} or \link{cr_build}
#' @param email The email that will authenticate the job set via \link{cr_email_set}
#' @param projectId The projectId
#'
#' @return A \link{HttpTarget} object for use in \link{cr_schedule}
#'
#' @details Ensure you have a service email with \link{cr_email_set} of format \code{service-{project-number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com} with Cloud Scheduler Service Agent role as per https://cloud.google.com/scheduler/docs/http-target-auth#add
#'
#' @export
#' @import assertthat
#' @family Cloud Scheduler functions
#'
#' @examples
#' cloudbuild <- system.file("cloudbuild/cloudbuild.yaml", package = "googleCloudRunner")
#' build1 <- cr_build_make(cloudbuild)
#' build1
#'
#' \dontrun{
#' cr_schedule("15 5 * * *", name="cloud-build-test1",
#'             httpTarget = cr_build_schedule_http(build1))
#'
#' # a cloud build you would like to schedule
#' itworks <- cr_build("cloudbuild.yaml", launch_browser = FALSE)
#'
#' # once working, pass in the build to the scheduler
#' cr_schedule("15 5 * * *", name="itworks-schedule",
#'             httpTarget = cr_build_schedule_http(itworks))
#'
#' }
#'
cr_build_schedule_http <- function(build,
                                   email = cr_email_get(),
                                   projectId = cr_project_get()){

  build <- as.gar_Build(build)
  build <- safe_set(build, "status", "QUEUED")

  HttpTarget(
    httpMethod = "POST",
    uri = sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/builds",
                  projectId),
    body = build,
    oauthToken = list(serviceAccountEmail = email)
  )
}


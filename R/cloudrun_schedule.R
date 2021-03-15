#' Create a Cloud Scheduler HTTP target for a Cloud Run URI
#'
#' This enables Cloud Scheduler to trigger Cloud Run
#'
#' @seealso https://cloud.google.com/run/docs/triggering/using-scheduler
#'
#' @param uri The URI of your Cloud Run application
#' @param http_method The HTTP verb you have set up your Cloud Run application to receive
#' @param email The email that will authenticate the job set via \link{cr_email_set}
#' @param body (optional) An R list object that will be turned into JSON via \link[jsonlite]{toJSON} and turned into a base64-encoded string if you are doing a POST, PUT or PATCH request.
#'
#' @return A \link{HttpTarget} object for use in \link{cr_schedule}
#'
#' @details Ensure you have a service email with \link{cr_email_set} of format \code{service-{project-number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com} with Cloud Scheduler Service Agent role as per https://cloud.google.com/scheduler/docs/http-target-auth#add
#'
#' @export
#' @import assertthat
#' @family Cloud Scheduler functions
#' @seealso \link{cr_build_schedule_http}
#' @examples
#'
#' run_me <- cr_run_schedule_http(
#'   "https://example-ewjogewawq-ew.a.run.app/echo?msg=blah",
#'   http_method = "GET"
#' )
#'
#' \dontrun{
#'
#' cr_schedule("cloud-run-scheduled", schedule = "16 4 * * *",
#'             httpTarget = run_me)
#'
#' }
#'
cr_run_schedule_http <- function(uri,
                                 http_method = "GET",
                                 body = NULL,
                                 email = cr_email_get()){

  assert_that(
    is.string(uri),
    is.string(http_method),
    is.string(email)
  )

  HttpTarget(
    httpMethod = http_method,
    uri = uri,
    body = body,
    oidcToken = list(
      serviceAccountEmail = email,
      audience = uri
    )
  )
}

#' Create a Cloud Scheduler HTTP target for a private Cloud Run URI
#'
#' This enables Cloud Scheduler to trigger Cloud Run endpoints when they are not public.
#'
#' @seealso https://cloud.google.com/run/docs/triggering/using-scheduler
#'
#' @param uri The URI of your Cloud Run application
#' @param http_method The HTTP verb you have set up your Cloud Run application to receive
#' @param email The service email that has invoke access to the Cloud Run application.  If using \link{cr_run} and derivatives to make the email this will include \code{(name)-cloudrun-invoker@(project-id).iam.gserviceaccount.com} - see \link{cr_run_email} to help make the email.
#' @param body (optional) An R list object that will be turned into JSON via \link[jsonlite]{toJSON} and turned into a base64-encoded string if you are doing a POST, PUT or PATCH request.
#'
#' @return A \link{HttpTarget} object for use in \link{cr_schedule}
#'
#' @details Ensure you have a service email with \link{cr_email_set} of format \code{service-{project-number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com} with Cloud Scheduler Service Agent role as per https://cloud.google.com/scheduler/docs/http-target-auth#add
#'
#' @export
#' @import assertthat
#' @family Cloud Scheduler functions
#' @family Cloud Run functions
#' @seealso \link{cr_schedule_http} and \link{cr_run} and \link{cr_deploy_run}
#' @examples
#' \dontrun{
#' # for unauthenticated apps create a HttpTarget
#' run_me <- HttpTarget(
#'   uri = "https://public-ewjogewawq-ew.a.run.app/echo?msg=blah",
#'   http_method = "GET"
#' )
#' cr_schedule("cloud-run-scheduled",
#'   schedule = "16 4 * * *",
#'   httpTarget = run_me
#' )
#'
#' # for authenticated Cloud Run apps - create with allowUnauthenticated=FALSE
#' cr_deploy_run("my-app", allowUnauthenticated = TRUE)
#' }
#'
#' # deploying via R will help create a service email called my-app-cloudrun-invoker
#' cr_run_email("my-app")
#' \dontrun{
#' # use that email to schedule the Cloud Run private micro-service
#'
#' # schedule the endpoint
#' my_run_name <- "my-app"
#' my_app <- cr_run_get(my_run_name)
#' email <- cr_run_email(my_run_name)
#' endpoint <- paste0(my_app$status$url, "/fetch_stuff")
#'
#' app_sched <- cr_run_schedule_http(endpoint,
#'   http_method = "GET",
#'   email = email
#' )
#'
#' cr_schedule("cloud-run-scheduled-1",
#'   schedule = "4 16 * * *",
#'   httpTarget = app_sched
#' )
#' }
#'
cr_run_schedule_http <- function(uri,
                                 email,
                                 http_method = "GET",
                                 body = NULL) {
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

#' Create an invoker email for use within authenticated Cloud Run
#'
#' @param name Name of the Cloud Run service
#' @param projectId The projectId where the Cloud Run service will run - set to NULL to only return the processed service name
#'
#' @export
#' @family Cloud Run functions
#' @examples
#'
#' cr_run_email("my-run-app", "my-project")
cr_run_email <- function(name, projectId = cr_project_get()) {
  service_name <- substr(paste0(name, "-invoker"), 1, 30)
  if (is.null(projectId)) {
    return(service_name)
  }

  sprintf("%s@%s.iam.gserviceaccount.com", service_name, projectId)
}

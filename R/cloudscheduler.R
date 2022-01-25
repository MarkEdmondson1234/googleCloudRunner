#' Creates or updates a Cloud Scheduler job.
#'
#' @seealso \href{https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/create}{Google Documentation for Cloud Scheduler}
#'
#' @inheritParams Job
#' @param projectId The GCP project to run within usually set with \link{cr_project_set}
#' @param region The region usually set with \link{cr_region_set}
#' @param overwrite If TRUE and an existing job with the same name exists, will overwrite it with the new parameters
#'
#' @importFrom googleAuthR gar_api_generator
#' @family Cloud Scheduler functions
#' @export
#' @return A \code{gar_scheduleJob} class object
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_schedule("test",
#'       "* * * * *",
#'       httpTarget = HttpTarget(uri="https://code.markedmondson.me"))
#'
#' # schedule a cloud build (no source)
#' build1 <- cr_build_make("cloudbuild.yaml")
#' cr_schedule("cloud-build-test", "15 5 * * *",
#'              httpTarget = cr_schedule_http(build1))
#'
#' # schedule a cloud build with code source from GCS bucket
#' my_gcs_source <- cr_build_upload_gcs("my_folder", bucket = cr_get_bucket())
#' build <- cr_build_make("cloudbuild.yaml", source = my_gcs_source)
#' cr_schedule("cloud-build-test2", "15 5 * * *",
#'             httpTarget = cr_schedule_http(build))
#'
#' # update a schedule with the same name - only supply what you want to change
#' cr_schedule("cloud-build-test2", "12 6 * * *", overwrite=TRUE)
#'
#' # By default will use the timezone as specified by Sys.timezone() - change
#' # this by supplying it directly
#' cr_schedule("timzone-utc", "12 2 * * *", timeZone = "UTC")
#'
#' # schedule private Cloud Run app
#' # for authenticated Cloud Run apps - create with allowUnauthenticated=FALSE
#' cr_deploy_run("my-app", allowUnauthenticated = TRUE)
#'
#' # deploying via R will help create a service email called my-app-invoker
#' cr_run_email("my-app")
#' #> "my-app-invoker@your-project.iam.gserviceaccount.com"
#'
#' # schedule the endpoint
#' my_app <- cr_run_get("my-app")
#'
#' endpoint <- paste0(my_app$status$url, "/fetch_stuff")
#'
#' app_sched <- cr_run_schedule_http(endpoint, http_method = "GET",
#'                                   email = cr_run_email("my-app"))
#'
#' cr_schedule("my-app-scheduled-1", schedule = "16 4 * * *",
#'             httpTarget = app_sched)
#'
#'
#' # creating build triggers that respond to pubsub events
#'
#' \dontrun{
#' # create a pubsub topic either in webUI or via library(googlePubSubR)
#' library(googlePubsubR)
#' pubsub_auth()
#' topics_create("test-topic")
#' }
#'
#' # create build trigger that will work from pub/subscription
#' pubsub_trigger <- cr_buildtrigger_pubsub("test-topic")
#' pubsub_trigger
#'
#' \dontrun{
#' # create the build trigger with in-line build
#' cr_buildtrigger(bb, name = "pubsub-triggered", trigger = pubsub_trigger)
#' # create scheduler that calls the pub/sub topic
#'
#' cr_schedule("cloud-build-pubsub",
#'             "15 5 * * *",
#'             pubsubTarget = cr_schedule_pubsub("test-topic"))
#'
#' }
#'
#' }
cr_schedule <- function(name,
                        schedule=NULL,
                        httpTarget=NULL,
                        pubsubTarget=NULL,
                        description=NULL,
                        overwrite=FALSE,
                        timeZone=Sys.timezone(),
                        region = cr_region_get(),
                        projectId = cr_project_get()
                        ) {

  assert_that(is.string(region))

  stem <- "https://cloudscheduler.googleapis.com/v1"

  the_name <- construct_name(name = name, region = region, project = projectId)
  job <- Job(schedule = schedule,
             name = the_name,
             httpTarget = httpTarget,
             pubsubTarget = pubsubTarget,
             description = description,
             timeZone = timeZone)

  if(!overwrite){
    assert_that(
      is.string(schedule),
      xor(is.null(httpTarget), is.null(pubsubTarget))
      )
  }

  the_url <-
    sprintf("%s/projects/%s/locations/%s/jobs",
            stem, projectId, region)
  # cloudscheduler.projects.locations.jobs.create
  f <- gar_api_generator(the_url, "POST",
                         data_parse_function = parse_schedule)

  if(overwrite){
    existing <- suppressMessages(
        cr_schedule_get(the_name, region = region, projectId = projectId)
      )

    if(!is.null(existing)){
      myMessage("Overwriting schedule job: ", name, level = 3)
      # https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/patch
      the_url <- paste0(stem, "/", the_name)
      updateMask <- rmNullObs(list(schedule = schedule,
                                   httpTarget = httpTarget,
                                   pubsubTarget = pubsubTarget,
                                   description = description))

      f <- gar_api_generator(the_url, "PATCH",
              data_parse_function = parse_schedule,
              pars_args = list(updateMask = paste(names(updateMask),
                                                  collapse = ",")))
    }

  }

  o <- f(the_body = job)

  # check for update operations
  if(o$state == "UPDATE_FAILED"){
    o <- retry_update_failed(job, f)
  }

  o

}

parse_schedule <- function(x){
  structure(x, class = "gar_scheduleJob")
}

retry_update_failed <- function(job, f) {
  myMessage("Update failed status, retrying", level = 3)
  i <- 0
  while(i < as.integer(getOption("googleAuthR.tryAttempts"))){
    o <- f(the_body = job)
    if(o$state != "UPDATE_FAILED"){
      myMessage("Retry successful", level = 3)
      return(o)
    }
    i <- i + 1
  }
  myMessage("Retry unsuccessful", level = 3)
  o
}

#' Lists Cloud Scheduler jobs.
#'
#' Lists cloud scheduler jobs including targeting, schedule and authentication
#'
#' @seealso \href{https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/list}{Google Documentation}
#'
#'
#' @param region The region to run within
#' @param projectId The projectId
#' @importFrom googleAuthR gar_api_generator gar_api_page
#' @export
#' @family Cloud Scheduler functions
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_schedule_list()
#'
#' }
cr_schedule_list <- function(region = cr_region_get(),
                             projectId = cr_project_get()) {

  url <-
    sprintf("https://cloudscheduler.googleapis.com/v1/projects/%s/locations/%s/jobs",
            projectId, region)

  # cloudscheduler.projects.locations.jobs.list
  pars <- list(pageToken = "", pageSize = 500)
  f <- gar_api_generator(url, "GET", pars_args = rmNullObs(pars),
                         data_parse_function = parse_schedule_list)

  o <- gar_api_page(f,
               page_f = function(x) x$nextPageToken,
               page_method = "param",
               page_arg = "pageToken")

  Reduce(rbind, o)


}

parse_schedule_list <- function(x){
  if(is.null(x$jobs)){
    return(data.frame())
  }

  df <- x$jobs
  cols <- intersect(names(df), c("name", "userUpdateTime",
                             "state", "scheduleTime",
                             "lastAttemptTime",
                             "schedule", "timeZone",
                             "attemptDeadline"))

  df[, cols]
}

#' Deletes a scheduled job.
#'
#' @seealso \href{https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/delete}{cloudscheduler.projects.locations.jobs.delete}
#'
#' @family Cloud Scheduler functions
#' @param x The name of the scheduled job or a \link{Job} object
#' @param region The region to run within
#' @param projectId The projectId
#' @param pubsub_cleanup If the Cloud Scheduler is pointing at a Build Trigger/PubSub as deployed by \link{cr_deploy_r} will attempt to clean up those resources too.
#' @importFrom googleAuthR gar_api_generator
#' @importFrom googlePubsubR topics_delete subscriptions_delete
#' @importFrom assertthat assert_that is.flag is.string
#' @export
#' @return \code{TRUE} if job not found or its deleted, \code{FALSE} if it could not delete the job
#'
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_schedule_delete("cloud-build-test1")
#'
#' }
cr_schedule_delete <- function(x,
                               region = cr_region_get(),
                               projectId = cr_project_get(),
                               pubsub_cleanup = FALSE){

  assert_that(
    is.flag(pubsub_cleanup),
    is.string(region),
    is.string(projectId)
  )

  the_job <- as.gar_scheduleJob(x)
  if(is.null(the_job)){
    myMessage("No schedule job found", call. = FALSE)
    return(TRUE)
  }

  the_name <- the_job$name

  url <- sprintf("https://cloudscheduler.googleapis.com/v1/%s", the_name)
  # cloudscheduler.projects.locations.jobs.delete
  f <- gar_api_generator(url, "DELETE", data_parse_function = function(x) TRUE)

  err_404 <- sprintf("Schedule: %s in project %s was not present to delete",
                     the_name, projectId)

  out <- handle_errs(f, http_404 = cli::cli_alert_info(err_404), return_404 = TRUE,
                     return_403 = FALSE)

  # here so it always deletes schedule at least
  if (pubsub_cleanup) delete_schedule_pubsub(the_name, projectId)

  out

}

delete_schedule_pubsub <- function(the_name, projectId){
  myMessage("PubSub triggered Cloud Build detected.  Attempting to delete topic and build trigger as well for", the_name, level = 3)

  build_trigger_guess <- paste0(underscore_to_dash(basename(the_name)), "-topic-trigger")

  myMessage("Fetching build trigger", build_trigger_guess, level = 3)
  the_buildtrigger <- cr_buildtrigger_get(build_trigger_guess, projectId = projectId)

  if(is.null(the_buildtrigger)){
    myMessage("Could not find build trigger",
              build_trigger_guess,
              "to delete. Aborting, you will need to delete it manually. ",
              level = 3)
    return(NULL)
  }

  if(!is.null(the_buildtrigger)){
    cr_buildtrigger_delete(the_buildtrigger$id, projectId = projectId)
  }

  the_pubsub <- tryCatch({
    # it deletes subscriptions too
    topics_delete(the_buildtrigger$pubsubConfig$topic)
    }, error = function(err){
    myMessage("Could not delete topic for ",
              the_name, "to delete. Aborting. ", err$message, level = 3)
    return(NULL)
  })

}

construct_name <- function(name, region, project){
  if(grepl("^projects", name)){
    return(name)
  }

  sprintf("projects/%s/locations/%s/jobs/%s",
          project, region, name)
}

#' Gets a scheduler job.
#'
#'
#' @seealso \href{https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/get}{Google Documentation}

#' @family Cloud Scheduler functions
#' @param name Required - a string or a schedule Job object
#' @param region The region to run within
#' @param projectId The projectId
#' @importFrom googleAuthR gar_api_generator
#' @export
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_schedule_get("cloud-build-test1")
#' }
cr_schedule_get <- function(name,
                            region = cr_region_get(),
                            projectId = cr_project_get()) {

  the_name <- construct_name(name = extract_schedule_name(name),
                            region = region,
                            project = projectId)

  url <- sprintf("https://cloudscheduler.googleapis.com/v1/%s", the_name)
  # cloudscheduler.projects.locations.jobs.get
  f <- gar_api_generator(url, "GET",
                         data_parse_function = parse_schedule)

  err_404 <- sprintf("Schedule: %s in project %s not found", name, projectId)

  handle_errs(f,
              http_404 = cli::cli_alert_danger(err_404),
              projectId = projectId)

}

#' Forces a job to run now.
#'
#' When this method is called, Cloud Scheduler will dispatch the job, even if the job is already running.
#'
#' @seealso \href{https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/run}{cloudscheduler.projects.locations.jobs.run}
#'
#' @family Cloud Scheduler functions
#' @param x The name of the scheduled job or a \link{Job} object
#' @param region The region to run within
#' @param projectId The projectId
#' @importFrom googleAuthR gar_api_generator
#' @export
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_schedule_run("cloud-build-test1")
#' }
cr_schedule_run <- function(x,
                            region = cr_region_get(),
                            projectId = cr_project_get()) {

  the_name <- construct_name(name = extract_schedule_name(x),
                            region = region,
                            project = projectId)

  url <- sprintf("https://cloudscheduler.googleapis.com/v1/%s:run",
                 the_name)
  # cloudscheduler.projects.locations.jobs.run
  f <- gar_api_generator(url, "POST",
                         data_parse_function = parse_schedule)

  f()

}

#' Pauses and resumes a scheduled job.
#'
#' If a job is paused then the system will stop executing the job until it is re-enabled via \link{cr_schedule_resume}.
#'
#' @details
#'
#' The state of the job is stored in state; if paused it will be set to Job.State.PAUSED. A job must be in Job.State.ENABLED to be paused.
#'
#' @family Cloud Scheduler functions
#' @seealso \href{https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/pause}{cloudscheduler.projects.locations.jobs.pause}
#'
#' @param x The name of the scheduled job or a \link{Job} object
#' @param region The region to run within
#' @param projectId The projectId
#' @importFrom googleAuthR gar_api_generator
#' @export
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_schedule_pause("cloud-build-test1")
#' cr_schedule_resume("cloud-build-test1")
#' }
cr_schedule_pause <- function(x,
                              region = cr_region_get(),
                              projectId = cr_project_get()) {

  the_name <- construct_name(name = extract_schedule_name(x),
                            region = region,
                            project = projectId)

  url <- sprintf("https://cloudscheduler.googleapis.com/v1/%s:pause",
                 the_name)

  # cloudscheduler.projects.locations.jobs.pause
  f <- gar_api_generator(url, "POST",
                         data_parse_function = parse_schedule)


  f()

}


#' Resume a job.
#'
#' @seealso \href{https://cloud.google.com/scheduler/}{cloudscheduler.projects.locations.jobs.resume}
#'
#' @importFrom googleAuthR gar_api_generator
#' @export
#' @rdname cr_schedule_pause
cr_schedule_resume <- function(x,
                               region = cr_region_get(),
                               projectId = cr_project_get()) {

  the_name <- construct_name(name = extract_schedule_name(x),
                            region = region,
                            project = projectId)

  url <- sprintf("https://cloudscheduler.googleapis.com/v1/%s:resume",
                 the_name)
  # cloudscheduler.projects.locations.jobs.resume
  f <- gar_api_generator(url, "POST",
                         data_parse_function = parse_schedule)

  f()


}


#' HttpTarget Object
#'
#' @param headers A named list of HTTP headers e.g. \code{list(Blah = "yes", Boo = "no")}
#' @param body HTTP request body.  Just send in the R object/list, which will be base64encoded correctly
#' @param oauthToken If specified, an OAuth token will be generated and attached as an Authorization header in the HTTP request. This type of authorization should be used when sending requests to a GCP endpoint.
#' @param uri Required
#' @param oidcToken If specified, an OIDC token will be generated and attached as an Authorization header in the HTTP request. This type of authorization should be used when sending requests to third party endpoints or Cloud Run.
#' @param httpMethod Which HTTP method to use for the request
#'
#' @return HttpTarget object
#'
#' @seealso https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs#HttpTarget
#'
#' @family Cloud Scheduler functions
#' @export
#' @importFrom jsonlite toJSON
#' @importFrom openssl base64_encode base64_decode
HttpTarget <- function(headers = NULL, body = NULL, oauthToken = NULL,
                       uri = NULL, oidcToken = NULL, httpMethod = NULL) {

  if(!is.null(headers)){
    assert_that(
      is.list(headers),
      is.character(names(headers))
    )
  }

  the_body <- toJSON(body, auto_unbox = TRUE)
  myMessage("Body parsed: ", the_body, level = 2)

  if(!is.null(body)){
    body <- base64_encode(the_body, linebreaks = FALSE)
    if(getOption("googleAuthR.verbose") < 3){
      myMessage("Body unencoded: ", rawToChar(base64_decode(body)))
    }
  }

  obj <- rmNullObs(list(headers = headers,
                        body = body,
                        oauthToken = oauthToken,
                        uri = uri,
                        oidcToken = oidcToken,
                        httpMethod = httpMethod))

  myMessage("HttpTarget Object: ", obj, level = 2)
  structure(obj,
            class = c("gar_HttpTarget", "list"))
}

#' Job Schedule Object
#'
#' @details
#'
#' Configuration for a job.The maximum allowed size for a job is 100KB.
#'
#' @param attemptDeadline The deadline for job attempts
#' @param pubsubTarget A Pub/Sub target object \link{PubsubTarget} such as created via \link{cr_schedule_pubsub}
#' @param httpTarget A HTTP target object \link{HttpTarget}
#' @param timeZone Specifies the time zone to be used in interpreting schedule. If set to \code{NULL} will be "UTC". Note that some time zones include a provision for daylight savings time.
#' @param description Optionally caller-specified in CreateJob or
#' @param appEngineHttpTarget App Engine HTTP target
#' @param status Output only
#' @param retryConfig Settings that determine the retry behavior
#' @param state Output only
#' @param name Name to call your scheduled job
#' @param lastAttemptTime Output only
#' @param scheduleTime Output only
#' @param schedule A cron schedule e.g. \code{"15 5 * * *"}
#' @param userUpdateTime Output only
#'
#' @return Job object
#'
#' @family Cloud Scheduler functions
#' @export
Job <- function(name = NULL,
                description = NULL,
                schedule = NULL,
                timeZone = NULL,
                userUpdateTime = NULL,
                state = NULL,
                status = NULL,
                scheduleTime = NULL,
                lastAttemptTime = NULL,
                retryConfig = NULL,
                attemptDeadline = NULL,
                pubsubTarget = NULL,
                appEngineHttpTarget = NULL,
                httpTarget = NULL) {

  structure(rmNullObs(list(attemptDeadline = attemptDeadline,
                           pubsubTarget = pubsubTarget,
                           httpTarget = httpTarget,
                           timeZone = timeZone,
                           description = description,
                           appEngineHttpTarget = appEngineHttpTarget,
                           status = status,
                           retryConfig = retryConfig,
                           state = state,
                           name = name,
                           lastAttemptTime = lastAttemptTime,
                           scheduleTime = scheduleTime,
                           schedule = schedule,
                           userUpdateTime = userUpdateTime)),
            class = c("gar_scheduleJob", "list"))
}

is.gar_scheduleJob <- function(x){
  inherits(x, "gar_scheduleJob")
}

as.gar_scheduleJob <- function(x,
                               region = cr_region_get(),
                               projectId = cr_project_get()){
  if(is.gar_scheduleJob(x)){
    the_job <- x
  } else {
    assert_that(is.string(x))
    the_job <- cr_schedule_get(x, region = region, projectId = projectId)
  }

  the_job
}


#' Pubsub Target Object (Cloud Scheduler)
#'
#' @details Pub/Sub target. The job will be delivered by publishing a message to the given Pub/Sub topic.
#'
#' @param topicName The name of the Cloud Pub/Sub topic to which messages will be published when a job is delivered.
#' @param data The message payload for PubsubMessage. An R object that will be turned into JSON via [jsonlite] and then base64 encoded into the PubSub format.
#' @param attributes Attributes for PubsubMessage.
#'
#' @return PubsubTarget object
#'
#' @family Cloud Scheduler functions
#' @export
#' @importFrom jsonlite toJSON
#' @importFrom openssl base64_encode base64_decode
PubsubTarget <- function(
  topicName = NULL,
  data = NULL,
  attributes = NULL
){

  if(!is.null(data)){
    the_data <- toJSON(data, auto_unbox = TRUE)
    myMessage("data json:", the_data, level = 2)
    the_data <- base64_encode(the_data, linebreaks = FALSE)
    myMessage("data encoded to: ", the_data, level = 2)
  }

  structure(rmNullObs(
    list(topicName = topicName,
         data = the_data,
         attributes = attributes)),
    class = c("gar_pubsubTarget", "list"))

}

is.gar_pubsubTarget <- function(x){
  inherits(x, "gar_pubsubTarget")
}


extract_schedule_name <- function(x){
  if(is.gar_scheduleJob(x)){
    return(x$name)
  } else {
    assert_that(is.string(x))
  }
  x
}

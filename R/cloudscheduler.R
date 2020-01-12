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
#'              httpTarget = cr_build_schedule_http(build1))
#'
#' # schedule a cloud build with code source from GCS bucket
#' my_gcs_source <- cr_build_upload_gcs("my_folder", bucket = cr_get_bucket())
#' build <- cr_build_make("cloudbuild.yaml", source = my_gcs_source))
#' cr_schedule("cloud-build-test2", "15 5 * * *",
#'             httpTarget = cr_build_schedule_http(build))
#'
#' # update a schedule with the same name - only supply what you want to change
#' cr_schedule("cloud-build-test2", "12 6 * * *", overwrite=TRUE)
#' }
cr_schedule <- function(name,
                        schedule=NULL,
                        httpTarget=NULL,
                        description=NULL,
                        overwrite=FALSE,
                        region = cr_region_get(),
                        projectId = cr_project_get()
                        ) {

  assert_that(
    is.string(region)
  )

  stem <- "https://cloudscheduler.googleapis.com/v1"

  the_name <- contruct_name(name = name, region = region, project = projectId)
  job <- Job(schedule=schedule,
             name = the_name,
             httpTarget = httpTarget,
             description = description)

  if(overwrite){
    scheds <- cr_schedule_list(region = region, projectId = projectId)
    if(the_name %in% scheds$name){
      myMessage("Overwriting schedule job: ", name, level=3)
# https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/patch
      the_url <- paste0(stem,"/", the_name)
      updateMask <- rmNullObs(list(schedule = schedule,
                             httpTarget = httpTarget,
                             description = description))

      f <- gar_api_generator(the_url, "PATCH",
              data_parse_function = parse_schedule,
              pars_args = list(updateMask = paste(names(updateMask),
                                                  collapse = ",")))
    }
  } else {
    assert_that(is.string(schedule))
    the_url <-
      sprintf("%s/projects/%s/locations/%s/jobs",
              stem, projectId, region)
    # cloudscheduler.projects.locations.jobs.create
    f <- gar_api_generator(the_url, "POST",
                           data_parse_function = parse_schedule)

  }

  stopifnot(inherits(job, "gar_scheduleJob"))

  o <- f(the_body = job)

  # check for update operations
  if(o$state == "UPDATE_FAILED"){
    o <- retry_update_failed(job, f)
  }

  o

}

parse_schedule <- function(x){
  structure(x,
            class = "gar_scheduleJob")
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
  pars = list(pageToken = "", pageSize = 500)
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

  x$jobs
}

#' Deletes a scheduled job.
#'
#' @seealso \href{https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/delete}{cloudscheduler.projects.locations.jobs.delete}
#'
#' @family Cloud Scheduler functions
#' @param x The name of the scheduled job or a \link{Job} object
#' @param region The region to run within
#' @param projectId The projectId
#' @importFrom googleAuthR gar_api_generator
#' @export
#'
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_schedule_delete("cloud-build-test1")
#' }
cr_schedule_delete <- function(x,
                               region = cr_region_get(),
                               projectId = cr_project_get()){

  the_name <- contruct_name(name = extract_schedule_name(x),
                            region = region,
                            project = projectId)

  url <- sprintf("https://cloudscheduler.googleapis.com/v1/%s", the_name)
  # cloudscheduler.projects.locations.jobs.delete
  f <- googleAuthR::gar_api_generator(url, "DELETE",
                                      data_parse_function = function(x) TRUE)
  f()

}

contruct_name <- function(name, region, project){
  if(grepl("^projects", name)){
    return(name)
  }

  sprintf("projects/%s/locations/%s/jobs/%s",
          project, region, name)
}

extract_schedule_name <- function(x){
  if(is.gar_scheduleJob(x)){
     return(x$name)
  } else {
    assert_that(is.string(x))
  }

  x
}

#' Gets a scheduler job.
#'
#'
#' @seealso \href{https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/get}{Google Documentation}

#' @family Cloud Scheduler functions
#' @param name Required
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

  the_name <- contruct_name(name = name,
                            region = region,
                            project = projectId)

  url <- sprintf("https://cloudscheduler.googleapis.com/v1/%s", the_name)
  # cloudscheduler.projects.locations.jobs.get
  f <- gar_api_generator(url, "GET",
                         data_parse_function = parse_schedule)
  f()

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

  the_name <- contruct_name(name = extract_schedule_name(x),
                            region = region,
                            project = projectId)

  url <- sprintf("https://cloudscheduler.googleapis.com/v1/%s:run",
                 the_name)
  # cloudscheduler.projects.locations.jobs.run
  f <- gar_api_generator(url,"POST",
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

  the_name <- contruct_name(name = extract_schedule_name(x),
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

  the_name <- contruct_name(name = extract_schedule_name(x),
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
#' @importFrom openssl base64_encode
HttpTarget <- function(headers = NULL, body = NULL, oauthToken = NULL,
                       uri = NULL, oidcToken = NULL, httpMethod = NULL) {

  if(!is.null(headers)){
    assert_that(
      is.list(headers),
      is.character(names(headers))
    )
  }

  if(!is.null(body)){
    body <- base64_encode(toJSON(body, auto_unbox = TRUE),linebreaks = FALSE)
  }

  structure(rmNullObs(list(headers = headers, body = body, oauthToken = oauthToken,
                 uri = uri, oidcToken = oidcToken, httpMethod = httpMethod)),
            class = c("gar_HttpTarget", "list"))
}

#' Job Schedule Object
#'
#' @details
#'
#' Configuration for a job.The maximum allowed size for a job is 100KB.
#'
#' @param attemptDeadline The deadline for job attempts
#' @param pubsubTarget Pub/Sub target
#' @param httpTarget A HTTP target object \link{HttpTarget}
#' @param timeZone Specifies the time zone to be used in interpreting
#' @param description Optionally caller-specified in CreateJob or
#' @param appEngineHttpTarget App Engine HTTP target
#' @param status Output only
#' @param retryConfig Settings that determine the retry behavior
#' @param state Output only
#' @param name Optionally caller-specified in CreateJob, after
#' @param lastAttemptTime Output only
#' @param scheduleTime Output only
#' @param schedule A cron schedule e.g. \code{"15 5 * * *"}
#' @param userUpdateTime Output only
#'
#' @return Job object
#'
#' @family Cloud Scheduler functions
#' @export
Job <- function(attemptDeadline = NULL,
                pubsubTarget = NULL,
                httpTarget = NULL,
                timeZone = NULL,
                description = NULL,
                appEngineHttpTarget = NULL,
                status = NULL,
                retryConfig = NULL,
                state = NULL,
                name = NULL,
                lastAttemptTime = NULL,
                scheduleTime = NULL,
                schedule = NULL,
                userUpdateTime = NULL) {

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
            class = c("gar_scheduleJob","list"))
}

is.gar_scheduleJob <- function(x){
  inherits(x, "gar_scheduleJob")
}


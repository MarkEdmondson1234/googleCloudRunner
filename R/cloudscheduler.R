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
    is.string(region),
    is.string(schedule)
  )

  stem <- "https://cloudscheduler.googleapis.com/v1"

  the_name <- sprintf("projects/%s/locations/%s/jobs/%s", projectId, region, name)
  job <- Job(schedule=schedule,
             name = the_name,
             httpTarget = httpTarget,
             description = description)

  if(overwrite){
    scheds <- cr_schedule_list(region = region, projectId = projectId)
    if(the_name %in% scheds$name){
      myMessage("Overwriting schedule job: ", name, level=3)
# https://cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs/patch
      the_url <-
        sprintf("%s/projects/%s/locations/%s/jobs/%s",
                stem, projectId, region, name)
      updateMask <- rmNullObs(list(schedule = schedule,
                             httpTarget = httpTarget,
                             description = description))

      f <- gar_api_generator(the_url, "PATCH",
              data_parse_function = parse_schedule,
              pars_args = list(updateMask = paste(names(updateMask),
                                                  collapse = ",")))
    }
  } else {
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
#'
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
                         data_parse_function = function(x) x$jobs)

  o <- gar_api_page(f,
               page_f = function(x) x$nextPageToken,
               page_method = "param",
               page_arg = "pageToken")

  Reduce(rbind, o)
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

#' Job Object
#'
#' @details
#' Autogenerated via \code{\link[googleAuthR]{gar_create_api_objects}}
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
#' @param schedule Required, except when used with UpdateJob
#' @param userUpdateTime Output only
#'
#' @return Job object
#'
#' @family Cloud Scheduler functions
#' @export
Job <- function(attemptDeadline = NULL, pubsubTarget = NULL, httpTarget = NULL, timeZone = NULL,
                description = NULL, appEngineHttpTarget = NULL, status = NULL, retryConfig = NULL,
                state = NULL, name = NULL, lastAttemptTime = NULL, scheduleTime = NULL, schedule = NULL,
                userUpdateTime = NULL) {
  structure(rmNullObs(list(attemptDeadline = attemptDeadline, pubsubTarget = pubsubTarget,
                 httpTarget = httpTarget, timeZone = timeZone, description = description,
                 appEngineHttpTarget = appEngineHttpTarget, status = status, retryConfig = retryConfig,
                 state = state, name = name, lastAttemptTime = lastAttemptTime, scheduleTime = scheduleTime,
                 schedule = schedule, userUpdateTime = userUpdateTime)),
            class = c("gar_scheduleJob","list"))
}


#' @rdname cr_schedule
#' @export
cr_build_schedule_http <- function(build,
                                   email = cr_email_get(),
                                   projectId = cr_project_get()){
  .Deprecated("cr_schedule_http")
  cr_schedule_http(build,
                   email = email,
                   projectId = projectId)
}

#' Create a Cloud Scheduler HTTP target from a Cloud Build object
#'
#' This enables Cloud Scheduler to trigger Cloud Builds
#'
#' @seealso https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds/create
#'
#' @param build A \link{Build} object created via \link{cr_build_make} or \link{cr_build}
#' @param email The email that will authenticate the job set via \link{cr_email_set}
#' @param projectId The projectId
#'
#' @return \code{cr_schedule_http} returns a \link{HttpTarget} object for use in \link{cr_schedule}
#'
#' @details Ensure you have a service email with \link{cr_email_set} of format \code{service-{project-number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com} with Cloud Scheduler Service Agent role as per https://cloud.google.com/scheduler/docs/http-target-auth#add
#'
#' @export
#' @import assertthat
#'
#'
#' @examples
#' cloudbuild <- system.file("cloudbuild/cloudbuild.yaml", package = "googleCloudRunner")
#' build1 <- cr_build_make(cloudbuild)
#' build1
#' \dontrun{
#' cr_schedule("cloud-build-test1",
#'   schedule = "15 5 * * *",
#'   httpTarget = cr_schedule_http(build1)
#' )
#'
#' # a cloud build you would like to schedule
#' itworks <- cr_build("cloudbuild.yaml", launch_browser = FALSE)
#'
#' # once working, pass in the build to the scheduler
#' cr_schedule("itworks-schedule",
#'   schedule = "15 5 * * *",
#'   httpTarget = cr_schedule_http(itworks)
#' )
#' }
#' @rdname cr_schedule
cr_schedule_http <- function(build,
                             email = cr_email_get(),
                             projectId = cr_project_get()) {

  # checks for build class here?

  build <- as.gar_Build(build)
  build <- safe_set(build, "status", "QUEUED")

  if (has_private_worker_pool(build)){
    uri <- paste0("https://cloudbuild.googleapis.com/v1/",build[["options"]][["pool"]][["name"]])
  } else {
    uri <- sprintf(
      "https://cloudbuild.googleapis.com/v1/projects/%s/builds",
      projectId
    )
  }

  HttpTarget(
    httpMethod = "POST",
    uri = uri,
    body = build,
    oauthToken = list(serviceAccountEmail = email)
  )
}

#' Schedule a Build object via HTTP or PubSub
#'
#' @details See also \link{cr_schedule} which you can use by to customise your schedule.
#'
#' @export
#' @param schedule A cron schedule e.g. \code{"15 5 * * *"}
#' @param build A Build object
#' @param schedule_type Whether to use HTTP or PubSub styled schedules
#' @param ... additional arguments to pass to \link{cr_schedule}
#' @inheritParams cr_schedule_http
#' @inheritDotParams cr_schedule
#' @return \code{cr_schedule_build} returns a cloud scheduler \link{Job} object
cr_schedule_build <- function(build,
                              schedule,
                              schedule_type = c("http", "pubsub"),
                              email = cr_email_get(),
                              projectId = cr_project_get(),
                              ...) {

  schedule_type <- match.arg(schedule_type)

  if(schedule_type == "http"){
    https <- cr_schedule_http(build,
                              email = email,
                              projectId = projectId)

    # schedule http API call to Cloud Build
    out <- cr_schedule(
      schedule = schedule,
      httpTarget = https,
      ...
    )
  } else if(schedule_type == "pubsub"){

    dots <- list(...)
    if(is.null(dots$name)){
      run_name <- paste0("cr_schedule_build_",
                         format(Sys.time(), format = "%Y%m%d%H%M%S"))
    } else {
      run_name <- dots$name
      dots$name <- NULL
    }

    # creates topic and build trigger
    pubsub_target <- create_pubsub_target(build = build,
                                          schedule_pubsub = dots$pubsubTarget,
                                          run_name = run_name)

    myMessage("Creating Cloud Schedule to trigger PubSub topicName:",
              pubsub_target$topicName,
              level = 3
    )
    # Schedule a pubsub message to the topic that triggers a BuildTrigger
    out <- do.call(cr_schedule,
                   args = c(dots,
                            list(name = run_name,
                                 schedule = schedule,
                                 pubsubTarget = pubsub_target))
    )

  }

  out

}

check_pubsub_topic <- function(schedule_pubsub, run_name){
  if (!is.null(schedule_pubsub)) {
    assert_that(is.gar_pubsubTarget(schedule_pubsub))
    topic_basename <- basename(schedule_pubsub$topicName)
    return(topic_basename)
  }

  check_package_installed("googlePubsubR")
  suppressMessages(googlePubsubR::ps_project_set(cr_project_get()))

  topic_basename <- paste0(run_name, "-topic")

  myMessage("Creating PubSub topic:", topic_basename, level = 3)
  topic_created <- tryCatch(
    googlePubsubR::topics_create(topic_basename),
    error = function(err) {
      stop("Could not create topic:",
           topic_basename,
           err$message,
           call. = FALSE
      )
    }
  )

  topic_basename

}

create_pubsub_target <- function(build, schedule_pubsub, run_name) {

  topic_basename <- check_pubsub_topic(schedule_pubsub, run_name)

  pubsub_target <- cr_schedule_pubsub(topic_basename)
  # check PubSub topic is there:
  topic_got <- googlePubsubR::topics_get(topic_basename)

  # May only contain alphanumeric characters and dashes
  trigger_name <- underscore_to_dash(paste0(basename(topic_got$name),
                                            "-trigger"))

  myMessage("Creating BuildTrigger subscription:", trigger_name, level = 3)
  # Create a build trigger that will run when the pubsub topic is called
  cr_buildtrigger(build,
                  name = trigger_name,
                  trigger = cr_buildtrigger_pubsub(basename(topic_got$name)))

  pubsub_target

}


#' Create a PubSub Target object for Cloud Scheduler
#'
#' @inheritParams PubsubTarget
#' @param PubsubMessage A \code{PubsubMessage} object generated via \link[googlePubsubR]{PubsubMessage}.  If used, then do not send in `data` or `attributes` arguments as will be redundant since this variable will hold the information.
#' @param projectId The projectId for where the topic sits
#' @param topicName The name of the Cloud Pub/Sub topic or a Topic object from \link[googlePubsubR]{topics_get}
#' @family Cloud Scheduler functions
#' @export
#' @importFrom jsonlite toJSON
#' @import googlePubsubR
#' @return \code{cr_schedule_pubsub} returns a \link{PubsubTarget} object for use within \link{cr_schedule} or \link{cr_schedule_build}
#'
#' @details
#'
#' You can parametrise builds by sending in values within PubSub. To read the data in the message set a substitution variable that picks up the data.  For example \code{_VAR1=$(body.message.data.var1)}
#'
#' If your schedule to PubSub fails with a permission error, try turning the Cloud Scheduler API off and on again the Cloud Console, which will refresh the Google permissions.
#'
#' @examples
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
#'   package = "googleCloudRunner"
#' )
#' bb <- cr_build_make(cloudbuild)
#' \dontrun{
#' # create a pubsub topic either in Google Console webUI or library(googlePubSubR)
#' library(googlePubsubR)
#' pubsub_auth()
#' topics_create("test-topic")
#' }
#'
#' # create build trigger that will watch for messages to your created topic
#' pubsub_trigger <- cr_buildtrigger_pubsub("test-topic")
#' pubsub_trigger
#' \dontrun{
#' # create the build trigger with in-line build
#' cr_buildtrigger(bb, name = "pubsub-triggered", trigger = pubsub_trigger)
#'
#'
#' # create scheduler that calls the pub/sub topic
#' cr_schedule("cloud-build-pubsub",
#'   "15 5 * * *",
#'   pubsubTarget = cr_schedule_pubsub("test-topic")
#' )
#' }
#'
#' # builds can be also parametrised to respond to parameters within your pubsub topic
#' # this cloudbuild echos back the value sent in 'var1'
#' cloudbuild <- system.file("cloudbuild/cloudbuild_substitutions.yml",
#'   package = "googleCloudRunner"
#' )
#' the_build <- cr_build_make(cloudbuild)
#'
#' # var1 is sent via Pubsub to the buildtrigger
#' message <- list(var1 = "hello mum")
#' send_me <- jsonlite::base64_enc(jsonlite::toJSON(message))
#'
#' # create build trigger that will work from pub/subscription
#' pubsub_trigger <- cr_buildtrigger_pubsub("test-topic")
#' \dontrun{
#' cr_buildtrigger(the_build, name = "pubsub-triggered-subs", trigger = pubsub_trigger)
#'
#' # create scheduler that calls the pub/sub topic with a parameter
#' cr_schedule("cloud-build-pubsub",
#'   "15 5 * * *",
#'   pubsubTarget = cr_schedule_pubsub("test-topic",
#'     data = send_me
#'   )
#' )
#' }
#' @rdname cr_schedule
cr_schedule_pubsub <- function(topicName,
                               PubsubMessage = NULL,
                               data = NULL,
                               attributes = NULL,
                               projectId = cr_project_get()) {

  assert_that(
    is.string(projectId)
  )

  if(is.string(topicName)){
    the_name <- sprintf("projects/%s/topics/%s", projectId, topicName)
  } else if(inherits(topicName, "Topic")){
    the_name <- topicName$name
  }

  assert_that(is.string(the_name))

  if (is.null(data)) {
    the_data <- the_name
  } else {
    the_data <- data
  }

  the_attributes <- attributes
  if (!is.null(PubsubMessage)) {
    if (!inherits(PubsubMessage, "PubsubMessage")) {
      stop("Not a PubsubMessage object passed to function.", call. = FALSE)
    }

    the_data <- PubsubMessage$data
    the_attributes <- PubsubMessage$attributes
  }

  PubsubTarget(
    topicName = the_name,
    data = the_data,
    attributes = the_attributes
  )
}

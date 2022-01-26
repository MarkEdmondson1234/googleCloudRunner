#' Download logs from a Cloud Build
#'
#' This lets you download the logs to your local R session, rather than viewing them in the Cloud Console.
#'
#' @param built The built object from \link{cr_build_status} or \link{cr_build_wait}
#' @param log_url You can optionally instead of \code{built} provide the direct gs:// URI to the log here.  It is in the format \code{gs://{{bucket}}/log-{{buildId}}.txt}
#'
#' @details
#'
#' By default, Cloud Build stores your build logs in a Google-created Cloud Storage bucket. You can view build logs store in the Google-created Cloud Storage bucket, but you cannot make any other changes to it. If you require full control over your logs bucket, store the logs in a user-created Cloud Storage bucket.
#'
#'
#' @export
#' @seealso \url{https://cloud.google.com/build/docs/securing-builds/store-manage-build-logs}
#' @family Cloud Build functions
#' @examples
#' \dontrun{
#' s_yaml <- cr_build_yaml(steps = cr_buildstep("gcloud", "version"))
#' build <- cr_build_make(s_yaml)
#' built <- cr_build(build)
#' the_build <- cr_build_wait(built)
#' cr_build_logs(the_build)
#' # [1] "starting build \"6ce86e05-b0b1-4070-a849-05ec9020fd3b\""
#' # [2] ""
#' # [3] "FETCHSOURCE"
#' # [4] "BUILD"
#' # [5] "Already have image (with digest): gcr.io/cloud-builders/gcloud"
#' # [6] "Google Cloud SDK 325.0.0"
#' # [7] "alpha 2021.01.22"
#' # [8] "app-engine-go 1.9.71"
#' # ...
#' }
cr_build_logs <- function(built = NULL, log_url = NULL) {
  if (is.null(built) && is.null(log_url)) {
    stop("Must supply one of built or log_url", call. = FALSE)
  }

  if (is.null(log_url)) {
    assert_that(is.gar_Build(built))
    log_url <- make_bucket_log_url(built)
  }

  error_log <-
    "Could not download logs - check you have Viewer role for auth key"

  if (is.na(log_url)) {
    return(error_log)
  }

  logs <- tryCatch(
    suppressMessages(googleCloudStorageR::gcs_get_object(log_url)),
    error = function(err) {
      NULL
    }
  )

  if(is.null(logs)){
    myMessage(error_log, level = 3)
    return(error_log)
  }

  readLines(textConnection(logs))
}

make_bucket_log_url <- function(x) {
  if (!is.null(x$logsBucket) && !is.null(x$id)) {
    return(sprintf("%s/log-%s.txt", x$logsBucket, x$id))
  }
  NA
}

#' Get the last build logs for a trigger name
#'
#' @param trigger_name The trigger name to check, will be used to look up trigger_id
#' @param trigger_id If supplied, trigger_name will be ignored
#' @param projectId The project containing the trigger_id
#'
#' @seealso \link{cr_build_logs_badger} to see logs for a badger created build
#'
#' @export
#' @examples
#' \dontrun{
#'
#' # get your trigger name
#' ts <- cr_buildtrigger_list()
#' ts$buildTriggerName
#'
#' my_trigger <- "package-checks"
#' last_logs <- cr_buildtrigger_logs(my_trigger)
#'
#' my_trigger_id <- "0a3cade0-425f-4adc-b86b-14cde51af674"
#' last_logs <- cr_buildtrigger_logs(trigger_id = my_trigger_id)
#' }
#' @rdname cr_build_logs
cr_buildtrigger_logs <- function(trigger_name = NULL,
                                 trigger_id = NULL,
                                 projectId = cr_project_get()) {
  if (is.null(trigger_name) && is.null(trigger_id)) {
    stop("Must supply one of trigger_name or trigger_id", call. = FALSE)
  }
  cli::cli_process_start("Downloading logs")

  if (is.null(trigger_id)) {
    cli::cli_status_update(msg = "{symbol$arrow_right} Downloading buildtriggers")
    ts <- cr_buildtrigger_list(projectId = projectId)

    if (!trigger_name %in% ts$buildTriggerName) {
      stop("Could not find trigger with name: ", trigger_name,
        "in projectId:", projectId,
        call. = FALSE
      )
    }

    trigger_id <- ts[ts$buildTriggerName == trigger_name, "buildTriggerId"]
  }

  gcr_bt <- cr_build_list_filter(
    "trigger_id",
    value = trigger_id
  )
  cli::cli_status_update(msg = "{symbol$arrow_right} Downloading builds")
  gcr_builds <- cr_build_list(gcr_bt, projectId = projectId)

  if (is.null(gcr_builds)) {
    stop("Could not find any builds with filter ", gcr_bt,
      " for projectId: ", projectId,
      call. = FALSE
    )
  }

  # get logs for last build
  last_build <- gcr_builds[1, ]
  last_build_logs <- cr_build_logs(log_url = last_build$bucketLogUrl)

  cli::cli_process_done()
  cli::cli_h1("Build {last_build$status}")
  cli::cli_ul()
  cli::cli_li("BuildTrigger: {last_build$buildTriggerName} - {last_build$buildTriggerId}")
  cli::cli_li("Started: {last_build$buildStartTime} - Finished: {last_build$buildFinishTime}")
  cli::cli_end()
  cli::cli_alert_info("Last 10 lines: {last_build$logUrl}")

  cat(cli::col_grey(paste(utils::tail(last_build_logs, 10), collapse = "\n")))

  last_build_logs
}

#' Returns information about a previously requested build.
#'
#' The `Build` that is returned includes its status (such as `SUCCESS`,`FAILURE`, or `WORKING`), and timing information.
#'
#' @seealso \url{https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#Build.Status}
#'
#' @param projectId ID of the project
#' @param id ID of the build or a \code{BuildOperationMetadata} object
#' @importFrom googleAuthR gar_api_generator
#' @import assertthat
#' @export
#' @family Cloud Build functions
#' @return A gar_Build object \link{Build} or NULL if not found
cr_build_status <- function(id = .Last.value,
                            projectId = cr_project_get()) {
  the_id <- extract_build_id(id)

  if (has_private_worker_pool(id)){
    url <- sprintf(
      "https://cloudbuild.googleapis.com/v1/%s",
      id[["metadata"]][["build"]][["name"]]
    )
  } else{
    url <- sprintf(
      "https://cloudbuild.googleapis.com/v1/projects/%s/builds/%s",
      projectId, the_id
    )
  }

  # cloudbuild.projects.builds.get
  f <- gar_api_generator(url, "GET", data_parse_function = as.gar_Build)

  err_404 <- sprintf("Build: %s in project %s not found - returning NULL",
                     id, projectId)

  handle_errs(f,
              http_404 = cli::cli_alert_danger(err_404),
              projectId = projectId)

}

#' Download artifacts from a build
#'
#' If a completed build includes artifact files this downloads them to local files
#'
#' @param build A \link{Build} object that includes the artifact location
#' @param download_folder Where to download the artifact files
#' @param overwrite Whether to overwrite existing local data
#' @param path_regex A regex of files to fetch from the artifact bucket location.  This is due to not being able to support the path globs
#'
#' @details
#' If your artifacts are using file glob (e.g. \code{myfolder/**}) to decide which workspace files are uploaded to Cloud Storage, you will need to create a path_regex of similar functionality (\code{"^myfolder/"}).  This is not needed if you use absolute path names such as \code{"myfile.csv"}
#'
#' @export
#' @family Cloud Build functions
#' @import assertthat
#' @importFrom googleCloudStorageR gcs_list_objects gcs_get_object
#'
#' @seealso \href{https://cloud.google.com/build/docs/building/store-build-artifacts}{Storing images and artifacts}
#'
#' @examples
#' \dontrun{
#' #' r <- "write.csv(mtcars,file = 'artifact.csv')"
#' ba <- cr_build_yaml(
#'   steps = cr_buildstep_r(r),
#'   artifacts = cr_build_yaml_artifact("artifact.csv", bucket = "my-bucket")
#' )
#' ba
#'
#' build <- cr_build(ba)
#' built <- cr_build_wait(build)
#'
#' cr_build_artifacts(built)
#' }
#'
cr_build_artifacts <- function(build,
                               download_folder = getwd(),
                               overwrite = FALSE,
                               path_regex = NULL) {
  assert_that(
    is.gar_Build(build),
    !is.null(build$artifacts$objects),
    !is.null(build$artifacts$objects$location),
    !is.null(build$artifacts$objects$paths)
  )

  bucket <- build$artifacts$objects$location
  paths <- build$artifacts$objects$paths
  just_bucket <- gsub("(gs://.+?)/(.+)$", "\\1", bucket)
  if (dirname(bucket) == "gs:") {
    just_path <- NULL
  } else {
    just_path <- gsub("(gs://.+?)/(.+)$", "\\2", bucket)
  }

  cloud_files <- gcs_list_objects(basename(just_bucket),
    prefix = just_path
  )

  # does not support glob
  if (is.null(path_regex)) {
    cloud_files <- cloud_files[cloud_files$name %in% paths, ]
  } else {
    assert_that(is.string(path_regex))
    cloud_files <- cloud_files[grepl(path_regex, cloud_files$name), ]
  }

  lapply(cloud_files$name, function(x) {
    o <- paste0(just_bucket, x)
    gcs_get_object(o,
      saveToDisk = x,
      overwrite = overwrite
    )
  })

  cloud_files$name
}

#' Wait for a Build to run
#'
#' This will repeatedly call \link{cr_build_status} whilst the status is STATUS_UNKNOWN, QUEUED or WORKING
#'
#' @param op The operation build object to wait for
#' @param projectId The projectId
#' @export
#' @family Cloud Build functions
#' @return A gar_Build object \link{Build}
cr_build_wait <- function(op = .Last.value,
                          projectId = cr_project_get()) {
  the_id <- extract_build_id(op)

  init <- cr_build_status(the_id, projectId = projectId)
  if (!init$status %in% c("STATUS_UNKNOWN", "QUEUED", "WORKING")) {
    return(init)
  }

  status <- wait_f(init, projectId)
  logs <- cr_build_logs(status)
  cli::cli_rule()
  cli::cli_alert_info("Last 10 lines of build log.  Use cr_build_logs() to read more")
  cat(cli::col_grey(paste(utils::tail(logs, 10), collapse = "\n")))
  status
}

#' @noRd
#' @importFrom cli cli_alert_info cli_process_failed cli_process_done
#' @importFrom cli cli_status cli_status_update make_spinner cli_div
wait_f <- function(init, projectId) {
  op <- init
  wait <- TRUE

  sb <- cli_status("Launching Cloud Build...")
  favs <- c("bouncingBall", "triangle",
            "runner", "shark", "arrow3", "circleHalves")
  sp1 <- make_spinner(
    which = favs[sample.int(6, size = 1)],
    template = "{spin} - building "
  )
  cli_div(theme = list(span.status = list(color = "blue")))

  tick <- 0
  start_time <- Sys.time()
  build_time <- "Pending..."
  while (wait) {
    if (tick %% 5 == 0) {
      status <- cr_build_status(op, projectId = projectId)
    }

    build_time <- difftime_format(start_time, Sys.time())

    if (status$status %in%
      c("FAILURE", "INTERNAL_ERROR", "TIMEOUT", "CANCELLED", "EXPIRED")) {
      cli_process_failed(
        id = sb,
        msg_failed = "Build failed with status: {status$status} and took ~{.timestamp {build_time}}"
      )
      wait <- FALSE
    }

    if (status$status %in% c("STATUS_UNKNOWN", "QUEUED", "WORKING")) {
      cli_status_update(
        id = sb,
        msg = "{symbol$arrow_right} ------------------- Status: {.status {status$status}} ~{.timestamp {build_time}}"
      )
      sp1$spin()

      tick <- tick + 1
      Sys.sleep(1)
    }

    if (status$status == "SUCCESS") {

      cli_process_done(
        id = sb,
        msg_done = "Build finished with status: {status$status} and took ~{.timestamp {build_time}}"
      )
      wait <- FALSE
    }

    op <- status
  }

  status
}


extract_runtime <- function(start_time) {
  started <- tryCatch(
    timestamp_to_r(start_time),
    error = function(err) {
      # sometimes starttime is returned from API NULL, so we fill one in
      tt <- Sys.time()
      message("Could not parse starttime: ", start_time,
        " setting starttime to:", tt,
        level = 2
      )
      tt
    }
  )
  as.integer(difftime(Sys.time(), started, units = "secs"))
}

extract_timeout <- function(op = NULL) {
  if (is.BuildOperationMetadata(op)) {
    the_timeout <- as.integer(gsub("s", "", op$metadata$build$timeout))
  } else if (is.gar_Build(op)) {
    the_timeout <- as.integer(gsub("s", "", op$timeout))
  } else if (is.null(op)) {
    the_timeout <- 600L
  } else {
    assert_that(is.integer(op))
    the_timeout <- op
  }

  the_timeout
}

extract_build_id <- function(op) {
  if (is.BuildOperationMetadata(op)) {
    the_id <- op$metadata$build$id
  } else if (is.gar_Build(op)) {
    the_id <- op$id
  } else {
    assert_that(is.string(op))
    the_id <- op
  }

  the_id
}

parse_build_meta_to_obj <- function(o) {
  the_steps <- o$steps
  if (is.null(the_steps)) {
    the_steps <- o$metadata$build$steps
  }

  if (all(vapply(the_steps, inherits, what = "cr_buildstep", TRUE))) {
    parsed_steps <- the_steps
  } else if (is.data.frame(the_steps)) {
    parsed_steps <- unname(cr_buildstep_df(the_steps))
  } else {
    stop("Could not parse out build steps from given build meta object", call. = FALSE)
  }

  yml <- cr_build_yaml(
    steps = parsed_steps,
    timeout = o$timeout,
    logsBucket = o$logsBucket,
    options = o$options,
    substitutions = o$substitutions,
    tags = o$tags,
    secrets = o$secrets,
    images = o$images,
    artifacts = o$artifacts,
    serviceAccount = o$serviceAccount
  )

  cr_build_make(yml)
}

as.gar_Build <- function(x) {
  if (is.BuildOperationMetadata(x)) {
    # This may be excessively defensive. It's not clear to me why
    # we can't just call cr_build_status(x) for both cases.
    if (has_private_worker_pool(x)){
      bb <- cr_build_status(x)
    } else {
      bb <- cr_build_status(extract_build_id(x),
                            projectId = x$metadata$build$projectId
      )
    }
    o <- parse_build_meta_to_obj(bb)
  } else if (is.gar_Build(x)) {
    o <- x # maybe more here later...
  } else {
    class(x) <- c("gar_Build", class(x))
    o <- x
  }
  assert_that(is.gar_Build(o))

  if (is.data.frame(o$steps)) {
    o$steps <- cr_buildstep_df(o$steps)
  }

  o
}

is.gar_Build <- function(x) {
  inherits(x, "gar_Build")
}

#' Build Object
#'
#' @details
#' A build resource in the Cloud Build API.
#'
#' At a high level, a `Build` describes where to find source code, how to build it (for example, the builder image to run on the source), and where to store the built artifacts.
#'
#' @section Build Macros:
#' Fields can include the following variables, which will be expanded when the build is created:-
#'
#' \itemize{
#'   \item $PROJECT_ID: the project ID of the build.
#'   \item $BUILD_ID: the autogenerated ID of the build.
#'   \item $REPO_NAME: the source repository name specified by RepoSource.
#'   \item $BRANCH_NAME: the branch name specified by RepoSource.
#'   \item $TAG_NAME: the tag name specified by RepoSource.
#'   \item $REVISION_ID or $COMMIT_SHA: the commit SHA specified by RepoSource or  resolved from the specified branch or tag.
#'   \item  $SHORT_SHA: first 7 characters of $REVISION_ID or $COMMIT_SHA.
#' }
#'
#'
#' @param Build.substitutions The Build.substitutions object or list of objects
#' @param Build.timing The Build.timing object or list of objects
#' @param results Output only
#' @param logsBucket Google Cloud Storage bucket where logs should be written (see
#' @param steps Required
#' @param buildTriggerId Output only
#' @param id Output only
#' @param tags Tags for annotation of a `Build`
#' @param startTime Output only
#' @param substitutions Substitutions data for `Build` resource
#' @param timing Output only
#' @param sourceProvenance Output only
#' @param createTime Output only
#' @param images A list of images to be pushed upon the successful completion of all build
#' @param projectId Output only
#' @param logUrl Output only
#' @param finishTime Output only
#' @param source A \link{Source} object specifying the location of the source files to build, usually created by \link{cr_build_source}
#' @param options Special options for this build
#' @param timeout Amount of time that this build should be allowed to run, to second
#' @param status Output only
#' @param statusDetail Output only
#' @param artifacts Artifacts produced by the build that should be uploaded upon
#' @param secrets Secrets to decrypt using Cloud Key Management Service [deprecated]
#' @param availableSecrets preferred way to use Secrets, via Secret Manager
#' @param serviceAccount service account email to be used for the build
#'
#' @return Build object
#'
#' @family Cloud Build functions
#' @export
Build <- function(Build.substitutions = NULL,
                  Build.timing = NULL,
                  results = NULL,
                  logsBucket = NULL,
                  steps = NULL,
                  buildTriggerId = NULL,
                  id = NULL,
                  tags = NULL,
                  startTime = NULL,
                  substitutions = NULL,
                  timing = NULL,
                  sourceProvenance = NULL,
                  createTime = NULL,
                  images = NULL,
                  projectId = NULL,
                  logUrl = NULL,
                  finishTime = NULL,
                  source = NULL,
                  options = NULL,
                  timeout = NULL,
                  status = NULL,
                  statusDetail = NULL,
                  artifacts = NULL,
                  secrets = NULL,
                  availableSecrets = NULL,
                  serviceAccount = NULL) {
  structure(rmNullObs(list(
    Build.substitutions = Build.substitutions,
    Build.timing = Build.timing,
    results = results,
    logsBucket = logsBucket,
    steps = steps,
    buildTriggerId = buildTriggerId,
    id = id,
    tags = tags,
    startTime = startTime,
    substitutions = substitutions,
    timing = timing,
    sourceProvenance = sourceProvenance,
    createTime = createTime,
    images = images,
    projectId = projectId,
    logUrl = logUrl,
    finishTime = finishTime,
    source = source,
    options = options,
    timeout = timeout,
    status = status,
    statusDetail = statusDetail,
    artifacts = artifacts,
    secrets = secrets,
    availableSecrets = availableSecrets,
    serviceAccount = serviceAccount
  )),
  class = c("gar_Build", "list")
  )
}

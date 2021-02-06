#' Lists the build
#'
#' Get a list of builds within your project
#'
#' @param projectId ID of the project
#' @param pageSize How many builds to fetch per page
#' @param filter Text filter for the list - use \code{cr_build_list_filter()} or a raw string
#' @param data_frame_output If TRUE will output a data.frame of a subset of info from the builds, merged with the list of triggers from \link{cr_buildtrigger_list}.  Set to FALSE to return a list of Build objects similar to output from \link{cr_build_status}
#'
#' @details
#'
#' When \code{data_frame_output=TRUE} results are sorted with the latest buildStartTime in the first row
#'
#' If filter is \code{NULL} then this will return all historic builds.  To use filters, ensure you use \code{""} and not \code{''} to quote the fields e.g. \code{'status!="SUCCESS"'} and \code{'status="SUCCESS"'} - see \href{Filtering build results docs}{https://cloud.google.com/cloud-build/docs/view-build-results#filtering_build_results_using_queries}.  \code{cr_build_list_filter} helps you construct valid filters.  More complex filters can be done using a combination of \link{paste} and \code{cr_build_list_filter()} - see examples
#'
#' @seealso \url{https://cloud.google.com/cloud-build/docs/api/reference/rest/v1/projects.builds/list}
#'
#' @importFrom googleAuthR gar_api_generator gar_api_page
#' @import assertthat
#' @export
#' @family Cloud Build functions
#' @examples
#'
#' \dontrun{
#'
#'  # merge with buildtrigger list
#'  cr_build_list()
#'
#'  # output a list of build objects
#'  cr_build_list(data_frame_output=FALSE)
#'
#'  # output a list of builds that failed using raw string
#'  cr_build_list('status!="SUCCESS"')
#'
#'  # output builds for a specific trigger using raw string
#'  cr_build_list('trigger_id="af2c7ddc-e4eb-4170-b938-a4babb53bac6"')
#'
#'  # use cr_build_list_filter to help validate filters
#'  failed_builds <- cr_build_list_filter("status","!=","SUCCESS")
#'  cr_build_list(failed_builds)
#'
#'  f1 <- cr_build_list_filter(
#'    "trigger_id","=","af2c7ddc-e4eb-4170-b938-a4babb53bac6")
#'  cr_build_list(f1)
#'
#'  # do AND (and other) filters via paste() and cr_build_list_filter()
#'  cr_build_list(paste(f1, "AND", failed_builds))
#'
#'  # builds in last 5 days
#'  last_five <- cr_build_list_filter("create_time", ">", Sys.Date() - 5)
#'  cr_build_list(last_five)
#'
#'  # builds in last 60 mins
#'  last_hour <- cr_build_list_filter("create_time", ">", Sys.time() - 3600)
#'  cr_build_list(last_hour)
#'
#'  # builds for this package's buildtrigger
#'  gcr_trigger_id <- "0a3cade0-425f-4adc-b86b-14cde51af674"
#'  gcr_bt <- cr_build_list_filter(
#'              "trigger_id",
#'              value = gcr_trigger_id)
#'  gcr_builds <- cr_build_list(gcr_bt)
#'
#'  # get logs for last build
#'  last_build <- gcr_builds[1,]
#'  last_build_logs <- cr_build_logs(log_url = last_build$bucketLogUrl)
#'  tail(last_logs, 10)
#'
#' }
cr_build_list <- function(filter = NULL,
                          projectId = cr_project_get(),
                          pageSize = 1000,
                          data_frame_output = TRUE){

  url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/builds",
                 projectId)

  pars <- list(
    pageSize = pageSize
  )
  if(!is.null(filter)){
    pars <- c(list(filter=filter), pars)
  }

  # cloudbuild.projects.builds.list
  f <- gar_api_generator(url, "GET",
                         pars_args = pars,
                         data_parse_function = function(x) x,
                         simplifyVector = FALSE,
                         checkTrailingSlash = FALSE)

  o <- f()

  # no paging required, return
  if(is.null(o$nextPageToken)){
    build_list <- o$builds
  } else {
    # need to page
    pars <- c(list(pageToken = o$nextPageToken), pars)
    # cloudbuild.projects.builds.list
    f2 <- gar_api_generator(url, "GET",
                            pars_args = pars,
                            data_parse_function = function(x) x,
                            simplifyVector = FALSE,
                            checkTrailingSlash = FALSE)
    results <- gar_api_page(f2,
                            page_f = function(x) x$nextPageToken,
                            page_method = "param",
                            page_arg = "pageToken")

    build_list <- unlist(lapply(results, function(x) x$builds), recursive = FALSE)
  }

  if(length(build_list) == 0){
    myMessage("No builds found", filter, level = 3)
    return(NULL)
  }

  bs <- lapply(build_list, as.gar_Build)
  ids <- unlist(lapply(bs, function(x) x$id))
  objs <- stats::setNames(bs, ids)

  # a list of build objects
  if(!data_frame_output) return(objs)

  myMessage("Parsing build objects into data.frame", level = 3)
  # make a data.frame output
  b_df <- Reduce(
    rbind,
    lapply(ids,
           function(y){
             x <- objs[[y]]
             data.frame(
               buildId = if_null_na(x$id),
               status = if_null_na(x$status),
               projectId = if_null_na(x$projectId),
               buildCreateTime = if_null_na(timestamp_to_r(x$createTime)),
               buildStartTime = if_null_na(timestamp_to_r(x$startTime)),
               buildFinishTime = if_null_na(timestamp_to_r(x$startTime)),
               timeout = if_null_na(x$timeout),
               logsBucket = if_null_na(x$logsBucket),
               buildTriggerId = if_null_na(x$buildTriggerId),
               logUrl = if_null_na(x$logUrl),
               bucketLogUrl = make_bucket_log_url(x),
               stringsAsFactors = FALSE)
           }
    )
  )

  bts_df <- cr_buildtrigger_list(projectId = projectId)

  # merge on buildTriggerId
  merged <- merge(b_df, bts_df, all.x = TRUE, sort = FALSE)

  merged[order(merged$buildStartTime, decreasing = TRUE), ]

}

#' Helper to parse filters for Build listings
#'
#' cr_build_list_filter outputs valid filters for \code{cr_build_list}'s filter argument
#'
#' @param field The field you want to filter on.  Will validate.
#' @param operator The type of comparision for the filter
#' @param value The value for the filter's field. Auto-formats \code{POSIXct} and \code{Date} objects
#'
#' @details
#'
#' Use \link{POSIXct} via functions like \link{Sys.time} to have them formatted into valid timestamps for time related fields, or \link{Date} objects via functions like \link{Sys.Date}
#'
#' @rdname cr_build_list
#' @export
cr_build_list_filter <- function(
  field,
  operator = c("=","!=",">",">=","<","<="),
  value){

  operator <- match.arg(operator)
  assert_that(is.string(field))

  the_fields <- c(
    "status",
    "build_id",
    "trigger_id",
    "source.storage_source.bucket",
    "source.storage_source.object",
    "source.repo_source.repo_name",
    "source.repo_source.branch_name",
    "source.repo_source.tag_name",
    "source.repo_source.commit_sha",
    "source_provenance.resolved_repo_source.commit_sha",
    "results.images.name",
    "results.images.digest",
    "options.requested_verify_option",
    "tags",
    "images",
    "create_time",
    "start_time",
    "finish_time")

  if(!field %in% the_fields){
    stop(sprintf("Field %s not present in supported fields: \n%s",
                 field, paste(the_fields, collapse = "\n")), call. = FALSE)
  }

  if(inherits(value, "POSIXct") || inherits(value, "Date")){
    value <- format(value, format = "%Y-%m-%dT%H:%M:%S+00:00", tz = "UTC")
  }

  assert_that(is.string(value))

  sprintf('%s %s "%s"', field, operator, value)

}

if_null_na <- function(thing){
  if(is.null(thing)) return(NA)
  thing
}



#' Returns information about a previously requested build.
#'
#' The `Build` that is returned includes its status (such as `SUCCESS`,`FAILURE`, or `WORKING`), and timing information.
#'
#' @seealso \url{https://cloud.google.com/cloud-build/docs/api/reference/rest/v1/projects.builds#Build.Status}
#'
#' @param projectId ID of the project
#' @param id ID of the build or a \code{BuildOperationMetadata} object
#' @importFrom googleAuthR gar_api_generator
#' @import assertthat
#' @export
#' @family Cloud Build functions
#' @return A gar_Build object \link{Build}
cr_build_status <- function(id = .Last.value,
                            projectId = cr_project_get()){

  the_id <- extract_build_id(id)

  url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/builds/%s",
                 projectId, the_id)


  # cloudbuild.projects.builds.get
  f <- gar_api_generator(url, "GET",
                         data_parse_function = as.gar_Build)

  f()

}

make_bucket_log_url <- function(x){
  if(!is.null(x$logsBucket) && !is.null(x$id)){
    return(sprintf("%s/log-%s.txt", x$logsBucket, x$id))
  }
  NA
}

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
#' @seealso \url{https://cloud.google.com/cloud-build/docs/securing-builds/store-manage-build-logs}
#' @family Cloud Build functions
#' @examples
#'
#' \dontrun{
#' s_yaml <- cr_build_yaml(steps = cr_buildstep( "gcloud","version"))
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
#'  }
cr_build_logs <- function(built = NULL, log_url = NULL){

  if(is.null(built) && is.null(log_url)){
    stop("Must supply one of built or log_url", call. = FALSE)
  }

  if(is.null(log_url)){
    assert_that(is.gar_Build(built))
    log_url <- make_bucket_log_url(built)
  }

  if(is.na(log_url)) return(NULL)

  logs <- suppressMessages(googleCloudStorageR::gcs_get_object(log_url))

  readLines(textConnection(logs))
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
#' @seealso \href{https://cloud.google.com/cloud-build/docs/building/store-build-artifacts}{Storing images and artifacts}
#'
#' @examples
#'
#' \dontrun{
#' #' r <- "write.csv(mtcars,file = 'artifact.csv')"
#' ba <- cr_build_yaml(
#'     steps = cr_buildstep_r(r),
#'     artifacts = cr_build_yaml_artifact('artifact.csv', bucket = "my-bucket")
#'     )
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
                               path_regex = NULL){

  assert_that(
    is.gar_Build(build),
    !is.null(build$artifacts$objects),
    !is.null(build$artifacts$objects$location),
    !is.null(build$artifacts$objects$paths)
  )

  bucket <- build$artifacts$objects$location
  paths <- build$artifacts$objects$paths
  just_bucket <- gsub("(gs://.+?)/(.+)$","\\1",bucket)
  if(dirname(bucket) == "gs:"){
    just_path <- NULL
  } else {
    just_path <- gsub("(gs://.+?)/(.+)$","\\2",bucket)
  }

  cloud_files <- gcs_list_objects(basename(just_bucket),
                                  prefix = just_path)

  # does not support glob
  if(is.null(path_regex)){
    cloud_files <- cloud_files[cloud_files$name %in% paths,]
  } else {
    assert_that(is.string(path_regex))
    cloud_files <- cloud_files[grepl(path_regex, cloud_files$name), ]
  }

  lapply(cloud_files$name, function(x){
    o <- paste0(just_bucket, x)
    gcs_get_object(o,
                   saveToDisk = x,
                   overwrite = overwrite)
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
                          projectId = cr_project_get()){

  the_id <- extract_build_id(op)

  init <- cr_build_status(the_id, projectId = projectId)
  if(!init$status %in% c("STATUS_UNKNOWN", "QUEUED", "WORKING")){
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
#' @import cli
wait_f <- function(init, projectId){
  op <- init
  wait <- TRUE

  cli_alert_info("Starting Cloud Build")

  while(wait){
    status <- cr_build_status(op, projectId = projectId)
    sb <- cli_status("{symbol$arrow_right} Running Build Id: {status$id}")

    if(status$status %in%
       c("FAILURE","INTERNAL_ERROR","TIMEOUT","CANCELLED","EXPIRED")){
      cli_process_failed(
        id = sb,
        msg_failed = "Build failed with status: {status$status}")
      wait <- FALSE
    }

    if(status$status %in% c("STATUS_UNKNOWN", "QUEUED", "WORKING")){
      cli_status_update(id = sb,
        msg = "{symbol$arrow_right} Running BuildId {status$id} Status: {status$status}")
      Sys.sleep(5)
    }

    if(status$status == "SUCCESS"){
      cli_process_done(
        id = sb,
        msg_done = "Build finished with status: {status$status}")
      wait <- FALSE
    }

    op <- status

  }

  status
}


extract_runtime <- function(start_time){
  started <- tryCatch(
    timestamp_to_r(start_time), error = function(err){
      # sometimes starttime is returned from API NULL, so we fill one in
      tt <- Sys.time()
      message("Could not parse starttime: ", start_time,
              " setting starttime to:", tt, level = 2)
      tt
    })
  as.integer(difftime(Sys.time(), started, units  = "secs"))
}

extract_timeout <- function(op=NULL){
  if(is.BuildOperationMetadata(op)){
    the_timeout <- as.integer(gsub("s", "", op$metadata$build$timeout))
  } else if(is.gar_Build(op)){
    the_timeout <- as.integer(gsub("s", "", op$timeout))
  } else if(is.null(op)){
    the_timeout <- 600L
  } else {
    assert_that(is.integer(op))
    the_timeout <- op
  }

  the_timeout
}

extract_build_id <- function(op){
  if(is.BuildOperationMetadata(op)){
    the_id <- op$metadata$build$id
  } else if (is.gar_Build(op)){
    the_id <- op$id
  } else {
    assert_that(is.string(op))
    the_id <- op
  }

  the_id
}

parse_build_meta_to_obj <- function(o){
  yml <- cr_build_yaml(
    steps = unname(cr_buildstep_df(o$steps)),
    timeout = o$timeout,
    logsBucket = o$logsBucket,
    options = o$options,
    substitutions = o$substitutions,
    tags = o$tags,
    secrets = o$secrets,
    images = o$images,
    artifacts = o$artifacts
  )

  cr_build_make(yml)
}

as.gar_Build <- function(x){
  if(is.BuildOperationMetadata(x)){
    bb <- cr_build_status(extract_build_id(x),
                          projectId = x$metadata$build$projectId)
    o <- parse_build_meta_to_obj(bb)
  } else if (is.gar_Build(x)) {
    o <- x # maybe more here later...
  } else {
    class(x) <- c("gar_Build", class(x))
    o <- x
  }
  assert_that(is.gar_Build(o))

  o
}

is.gar_Build <- function(x){
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
                  availableSecrets = NULL) {

  structure(rmNullObs(list(Build.substitutions = Build.substitutions,
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
                           availableSecrets = availableSecrets)),
            class = c("gar_Build", "list"))
}


#' Starts a build with the specified configuration.
#'
#' This method returns a long-running `Operation`, which includes the buildID. Pass the build ID to \link{cr_build_status} to determine the build status (such as `SUCCESS` or `FAILURE`).
#'
#'
#' @seealso \href{https://cloud.google.com/cloud-build/docs/}{Google Documentation for Cloud Build}
#'
#' @inheritParams Build
#' @param projectId ID of the project
#' @param x A cloudbuild.yaml file location or an R object that will be turned into yaml via \link[yaml]{as.yaml} or a \link{Build} object created by \link{cr_build_make} or from a previous build you want to rerun.
#' @param launch_browser Whether to launch the logs URL in a browser once deployed
#' @importFrom googleAuthR gar_api_generator
#' @importFrom yaml yaml.load_file
#' @import assertthat
#' @family Cloud Build functions
#' @export
#' @examples
#' cr_project_set("my-project")
#' my_gcs_source <- cr_build_source(StorageSource("my_code.tar.gz",
#'                                              bucket = "gs://my-bucket"))
#' my_gcs_source
#'
#' my_repo_source <- cr_build_source(RepoSource("github_username_my-repo.com",
#'                                            branchName="master"))
#' my_repo_source
#' \dontrun{
#'
#' # build from a cloudbuild.yaml file
#' cloudbuild_file <- system.file("cloudbuild/cloudbuild.yaml",
#'                                package="googleCloudRunner")
#'
#' # asynchronous, will launch log browser by default
#' b1 <- cr_build(cloudbuild_file)
#'
#' # synchronous waiting for build to finish
#' b2 <- cr_build_wait(b1)
#'
#' # the same results
#' cr_build_status(b1)
#' cr_build_status(b2)
#'
#' # build from a cloud storage source
#' build1 <- cr_build(cloudbuild_file,
#'                    source = my_gcs_source)
#' # build from a git repository source
#' build2 <- cr_build(cloudbuild_file,
#'                    source = my_repo_source)
#'
#' # you can send in results for previous builds to trigger
#' # the same build under a new Id
#' # will trigger build2 again
#' cr_build(build2)
#'
#' # a build with substitutions (Cloud Build macros)
#' cr_build(build2, substitutions = list(`_SUB` = "yo"))
#'
#' }
cr_build <- function(x,
                     source = NULL,
                     timeout=NULL,
                     images=NULL,
                     substitutions=NULL,
                     artifacts = NULL,
                     options = NULL,
                     projectId = cr_project_get(),
                     launch_browser = interactive()) {

  assert_that(
    is.flag(launch_browser),
    is.string(projectId)
  )

  timeout <- check_timeout(timeout)

  url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/builds",
                 projectId)

  if(is.gar_Build(x)){
    # turn existing build into a valid new build
    build <- safe_set(x, "status", "QUEUED")

  } else if(is.BuildOperationMetadata(x)){
    x <- as.gar_Build(x)
    build <- safe_set(x, "status", "QUEUED")
  } else {
    build <- cr_build_make(yaml = x,
                           source = source,
                           timeout = timeout,
                           images = images,
                           artifacts = artifacts,
                           options = options,
                           substitutions = substitutions)
  }


  parse_f <- function(x){
    structure(x,
              class = "BuildOperationMetadata")
  }
  # cloudbuild.projects.builds.create
  f <- gar_api_generator(url, "POST",
         data_parse_function = parse_f)
  stopifnot(is.gar_Build(build))

  o <- f(the_body = build)

  logs <- extract_logs(o)
  myMessage("Cloud Build started - logs: \n", logs, level = 3)

  if(launch_browser){
    utils::browseURL(logs)
  }

  invisible(o)
}

is.BuildOperationMetadata <- function(x){
  inherits(x, "BuildOperationMetadata")
}



extract_logs <- function(o){
  if(is.BuildOperationMetadata(o)){
    return(o$metadata$build$logUrl)
  } else if(is.gar_Build(o)){
    return(o$logUrl)
  } else {
    warning("Could not extract logUrl from class: ", class(o))
  }
}

#' Make a Cloud Build object out of a cloudbuild.yml file
#'
#' This creates a \link{Build} object via the standard cloudbuild.yaml format
#'
#' @seealso https://cloud.google.com/cloud-build/docs/build-config
#'
#' @inheritParams cr_build
#' @param yaml A \code{Yaml} object created from \link{cr_build_yaml} or a file location of a .yaml/.yml cloud build file
#' @param artifacts Artifacts that may be built via \link{cr_build_yaml_artifact}
#' @param options Options
#'
#' @export
#' @import assertthat
#' @family Cloud Build functions
#' @examples
#' cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
#'                            package = "googleCloudRunner")
#' cr_build_make(cloudbuild)
cr_build_make <- function(yaml,
                          source = NULL,
                          timeout=NULL,
                          images=NULL,
                          artifacts = NULL,
                          options = NULL,
                          substitutions = NULL){

  stepsy <- get_cr_yaml(yaml)
  if(is.null(stepsy$steps)){
    stop("Invalid cloudbuild yaml - 'steps:' not found.", call. = FALSE)
  }

  timeout <- check_timeout(timeout)
  if(is.null(timeout)){
    if(!is.null(stepsy$timeout)){
      timeout <- stepsy$timeout
    }
  }

  if(!is.null(source)){
    assert_that(is.gar_Source(source))
  }

  if(is.null(images)){
    if(!is.null(stepsy$images)){
      images <- stepsy$images
    }
  }

  if(is.null(artifacts)){
    if(!is.null(stepsy$artifacts)){
      artifacts <- stepsy$artifacts
    }
  }

  if(is.null(options)){
    if(!is.null(stepsy$options)){
      options <- stepsy$options
    }
  }

  if(is.null(substitutions)){
    if(!is.null(stepsy$substitutions)){
      substitutions <- stepsy$substitutions
    }
  }

  Build(steps = stepsy$steps,
        timeout = timeout,
        images = images,
        source = source,
        options = options,
        substitutions = substitutions,
        artifacts = artifacts)
}

#' Returns information about a previously requested build.
#'
#' The `Build` that is returned includes its status (such as `SUCCESS`,`FAILURE`, or `WORKING`), and timing information.
#'
#' @seealso https://cloud.google.com/cloud-build/docs/api/reference/rest/Shared.Types/Status
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
#' r <- "write.csv(mtcars,file = 'artifact.csv')"
#' ba <- cr_build_yaml(
#'     steps = cr_buildstep_r(r),
#'     artifacts = cr_build_yaml_artifact('artifact.csv', bucket = "my-bucket")
#'     )
#' ba
#' \dontrun{
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

  wait_f(init, projectId)

}

wait_f <- function(init, projectId){
  op <- init
  wait <- TRUE

  myMessage("Waiting for Cloud Build...", level = 3)

  timeout <- extract_timeout(op)

  pbf <- sprintf("(:spin) Build time: [:elapsedfull] (:percent of timeout: %ss)",
                 timeout)
  pb <- progress::progress_bar$new(
    total = extract_timeout(op),
    format = pbf,
    clear = FALSE
  )

  pb$tick(0)
  while(wait){
    status <- cr_build_status(op, projectId = projectId)
    pb$tick()
    if(!status$status %in% c("STATUS_UNKNOWN", "QUEUED", "WORKING")){
       wait <- FALSE
    }
    op <- status
    Sys.sleep(5)
  }
  pb$terminate()

  myMessage("Build finished with status:", status$status, level = 3)

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
#' @param secrets Secrets to decrypt using Cloud Key Management Service
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
                  secrets = NULL) {

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
                           secrets = secrets)),
            class = c("gar_Build", "list"))
}


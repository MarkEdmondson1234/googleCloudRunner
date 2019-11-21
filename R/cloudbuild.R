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
#'
#' my_gcs_source <- Source(storageSource=StorageSource("gs://my-bucket", "my_code.tar.gz"))
#' my_gcs_source
#'
#' my_repo_source <- Source(repoSource=RepoSource("https://my-repo.com", branchName="master"))
#' my_repo_source
#' \dontrun{
#'
#' # build from a cloudbuild.yaml file
#' cloudbuild_file <- system.file("cloudbuild/cloudbuild.yaml", package="googleCloudRunner")
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
#' # you can send in results for previous builds to trigger the same build under a new Id
#' # will trigger build2 again
#' cr_build(build2)
#'
#'
#' }
cr_build <- function(x,
                     source = NULL,
                     timeout=NULL,
                     images=NULL,
                     projectId = cr_project_get(),
                     launch_browser = interactive()) {

  assert_that(
    is.flag(launch_browser),
    is.string(projectId)
  )

  if(!is.null(timeout)){
    assert_that(is.numeric(timeout))
    timeout <- paste0(as.integer(timeout),"s")
  }
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
                           projectId = projectId)
  }


  # cloudbuild.projects.builds.create
  f <- gar_api_generator(url, "POST",
        data_parse_function = function(x) structure(x,
                                           class = "BuildOperationMetadata"))
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
#' @param yaml A \link{Yaml} object or a file location of a .yaml/.yml cloud build file
#' @export
#' @import assertthat
#' @family Cloud Build functions
#' @examples
#' cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
#'                            package = "googleCloudRunner")
#' cr_build_make(cloudbuild, projectId = "test-project")
cr_build_make <- function(yaml,
                          source = NULL,
                          timeout=NULL,
                          images=NULL,
                          projectId = cr_project_get()){

  assert_that(
    is.string(projectId)
  )

  stepsy <- get_cr_yaml(yaml)
  if(is.null(stepsy$steps)){
    stop("Invalid cloudbuild yaml - 'steps:' not found.", call. = FALSE)
  }

  if(!is.null(source)){
    assert_that(is.gar_Source(source))
  }

  if(is.null(images)){
    if(!is.null(stepsy$images)){
      images <- stepsy$images
    }
  }

  Build(steps = stepsy$steps,
        timeout = timeout,
        images = images,
        source = source)
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
          data_parse_function = function(x) as.gar_Build(x))
  f()

}

#' Wait for a Build to run
#'
#' This will repeatedly call \link{cr_build_status} whilst the status is STATUS_UNKNOWN, QUEUED or WORKING
#'
#' @param op The operation build object to wait for
#' @param projectId The projectId
#' @param task_id A possible RStudio job taskId to increment status upon
#' @export
#' @family Cloud Build functions
#' @return A gar_Build object \link{Build}
cr_build_wait <- function(op = .Last.value,
                          projectId = cr_project_get(),
                          task_id = NULL){

  the_id <- extract_build_id(op)

  if(is.null(task_id)){
    task_id <- rstudio_add_job(the_id,
                               timeout=extract_timeout(op))
  }

  wait_for <- c("STATUS_UNKNOWN", "QUEUED", "WORKING")

  init <- cr_build_status(the_id, projectId = projectId)
  if(!init$status %in% wait_for){
    return(init)
  }

  if(!rstudioapi::isAvailable()) cat("\nWaiting for build to finish:\n |=")

  rstudio_add_output(task_id,
                     paste("\n#Created Cloud Build, online logs:\n",
                           extract_logs(init)))

  op <- init
  wait <- TRUE
  while(wait){
    status <- cr_build_status(op, projectId = projectId)

    if(!rstudioapi::isAvailable()) cat("=")

    rstudio_add_progress(task_id, extract_runtime(status$startTime))
    rstudio_add_state(task_id, status$status)
    rstudio_add_output(task_id, paste("\nStatus:", status$status))

    if(!status$status %in% wait_for){
      wait <- FALSE
    }
    op <- status
    Sys.sleep(5)
  }

  if(!rstudioapi::isAvailable()) cat("| Build finished\n")

  status
}

extract_runtime <- function(start_time){
  started <- tryCatch(
    timestamp_to_r(start_time), error = function(err){
      stop("Could not parse starttime: ", start_time)
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

as.gar_Build <- function(x){
  if(is.BuildOperationMetadata(x)){
    o <- cr_build_status(extract_build_id(x),
                         projectId = x$metadata$build$projectId)
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
#' At a high level, a `Build` describes where to find source code, how to buildit (for example, the builder image to run on the source), and where to store the built artifacts.
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
#' @param source A \link{Source} object specifying the location of the source files to build
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

#' Write out a Build object to cloudbuild.yaml
#'
#' @param x A \link{Build} object perhaps created with \link{cr_build_make} or \link{Yaml} created
#' @param file Where to write the yaml file
#'
#' @export
#' @family Cloud Build functions, yaml functions
#' @examples
#'
#' # write from creating a Yaml object
#' image = "gcr.io/my-project/my-image$BUILD_ID"
#' run_yaml <- Yaml(steps = c(
#'     cr_buildstep("docker", c("build","-t",image,".")),
#'     cr_buildstep("docker", c("push",image)),
#'     cr_buildstep("gcloud", c("beta","run","deploy", "test1", "--image", image))),
#'   images = image)
#' cr_build_write(run_yaml)
#'
#' # write from a Build object
#' build <- cr_build_make(system.file("cloudbuild/cloudbuild.yaml",
#'                                    package = "googleCloudRunner"))
#' cr_build_write(build)
#'
cr_build_write <- function(x, file = "cloudbuild.yaml"){
  myMessage("Writing to ", file, level = 3)
  UseMethod("cr_build_write", x)
}

#' @export
cr_build_write.gar_Build <- function(x, file = "cloudbuild.yaml"){
  o <- rmNullObs(Yaml(
    steps = x$steps,
    images = x$images
  ))
  cr_build_write.cr_yaml(o, file)
}

#' @export
#' @importFrom yaml write_yaml
cr_build_write.cr_yaml <- function(x, file = "cloudbuild.yaml"){
  write_yaml(x, file = file)
}






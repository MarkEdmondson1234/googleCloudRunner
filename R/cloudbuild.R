#' Starts a build with the specified configuration.
#'
#' This method returns a long-running `Operation`, which includes the buildID. Pass the build ID to \link{cr_build_status} to determine the build status (such as `SUCCESS` or `FAILURE`).
#'
#'
#' @seealso \href{https://cloud.google.com/cloud-build/docs/}{Google Documentation for Cloud Build}
#'
#' @inheritParams Build
#' @param projectId ID of the project
#' @param yaml A cloudbuild.yaml with the steps to run for the build - either a file location or an R object that will be turned into yaml via \link[yaml]{as.yaml}
#' @param launch_browser Whether to launch the logs URL in a browser once deployed
#' @importFrom googleAuthR gar_api_generator
#' @importFrom yaml yaml.load_file
#' @import assertthat
#' @family Cloud Build functions
#' @export
#' @examples
#'
#' \dontrun{
#'
#' b1 <- cr_build("cloudbuild.yaml")
#' b2 <- cr_build_wait(b1)
#' cr_build_status(b1)
#' cr_build_status(b2)
#'
#' my_gcs_source <- Source(storageSource=StorageSource("gs://my-bucket", "my_code.tar.gz"))
#' my_repo_source <- Source(repoSource=RepoSource("https://my-repo.com", branchName="master"))
#'
#' build1 <- cr_build("cloudbuild.yaml", source = my_gcs_source)
#' build2 <- cr_build("cloudbuild.yaml", source = my_repo_source)
#'
#' }
cr_build <- function(yaml,
                     source = NULL,
                     timeout=NULL,
                     images=NULL,
                     projectId = cr_project_get(),
                     launch_browser = interactive()) {

  assert_that(
    is.flag(launch_browser),
    is.string(projectId)
  )
  url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/builds",
                 projectId)

  build <- cr_build_make(yaml = yaml,
                         source = source,
                         timeout = timeout,
                         images = images,
                         projectId = projectId)

  # cloudbuild.projects.builds.create
  f <- gar_api_generator(url, "POST",
        data_parse_function = function(x) structure(x,
                                           class = "BuildOperationMetadata"))
  stopifnot(is.gar_Build(build))

  o <- f(the_body = build)

  myMessage("Cloud Build started - logs: \n",
            o$metadata$build$logUrl,
            level = 3)

  if(launch_browser){
    utils::browseURL(o$metadata$build$logUrl)
  }

  invisible(o)
}

is.BuildOperationMetadata <- function(x){
  inherits(x, "BuildOperationMetadata")
}

#' Make a Cloud Build object out of a cloudbuild.yml file
#'
#' This creates a \link{Build} object via the standard cloudbuild.yaml format
#'
#' @seealso https://cloud.google.com/cloud-build/docs/build-config
#'
#' @inheritParams cr_build
#' @export
#' @import assertthat
#' @family Cloud Build functions
#' @examples
#' build1 <- cr_build_make("inst/cloudbuild/cloudbuild.yaml")
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

  if(!is.null(images)){
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
#'
#' @param projectId ID of the project
#' @param id ID of the build or a \code{BuildOperationMetadata} object
#' @importFrom googleAuthR gar_api_generator
#' @import assertthat
#' @export
#' @family Cloud Build functions
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
#' @export
#' @family Cloud Build functions
cr_build_wait <- function(op = .Last.value,
                          projectId = cr_project_get()){

  the_id <- extract_build_id(op)

  wait_for <- c("STATUS_UNKNOWN", "QUEUED", "WORKING")

  init <- cr_build_status(the_id, projectId = projectId)
  if(!init$status %in% wait_for){
    return(init)
  }

  cat("\nWaiting for build to finish:\n |=")

  op <- init
  wait <- TRUE
  while(wait){
    status <- cr_build_status(op, projectId = projectId)
    cat("=")
    if(!status$status %in% wait_for){
      wait <- FALSE
    }
    op <- status
    Sys.sleep(5)
  }

  cat("||\nBuild finished\n")
  status
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
  class(x) <- c("gar_Build", class(x))
  x
}

is.gar_Build <- function(x){
  inherits(x, "gar_Build")
}

#' Create a StorageSource
#'
#' This creates a \link{StorageSource} object after uploading to Google Cloud Storage
#'
#' @param local Local directory containing the Dockerfile etc. you wish to deploy
#' @param remote The name of the folder in your bucket
#' @param bucket The Google Cloud Storage bucket to uplaod to
#'
#' @details
#'
#' It copies the files into a folder call "deploy" in your working directory, then tars it for upload
#'
#' @export
#' @importFrom googleCloudStorageR gcs_upload
#' @examples
#'
#' \dontrun{
#'
#' storage <- cr_build_upload_gcs("my_folder")
#' my_gcs_source <- Source(storageSource=storage)
#' build1 <- cr_build("cloudbuild.yaml", source = my_gcs_source)
#'
#' }
#' @family Cloud Build functions
cr_build_upload_gcs <- function(local,
                                remote = paste0(local,format(Sys.time(), "%Y%m%d%H%M%S"),".tar.gz"),
                                bucket = cr_bucket_get()){

  tar_file <- paste0(basename(local), ".tar.gz")
  deploy_folder <- "deploy"

  dir.create(deploy_folder, showWarnings = FALSE)
  on.exit(unlink(deploy_folder))
  file.copy(list.files(local, recursive = TRUE, full.names = TRUE),
            deploy_folder, recursive = TRUE)

  tar(tar_file,
      files = deploy_folder,
      compression = "gzip")

  gcs_upload(tar_file, bucket = bucket, name = remote)

  StorageSource(
    bucket = bucket,
    object = remote
  )
}



#' Build Object
#'
#' @details
#' A build resource in the Cloud Build API.At a high level, a `Build` describes where to find source code, how to buildit (for example, the builder image to run on the source), and where to storethe built artifacts.
#' Fields can include the following variables, which will be expanded when the build is created:- $PROJECT_ID: the project ID of the build.- $BUILD_ID: the autogenerated ID of the build.- $REPO_NAME: the source repository name specified by RepoSource.- $BRANCH_NAME: the branch name specified by RepoSource.- $TAG_NAME: the tag name specified by RepoSource.- $REVISION_ID or $COMMIT_SHA: the commit SHA specified by RepoSource or  resolved from the specified branch or tag.- $SHORT_SHA: first 7 characters of $REVISION_ID or $COMMIT_SHA.
#'
#' @param Build.substitutions The \link{Build.substitutions} object or list of objects
#' @param Build.timing The \link{Build.timing} object or list of objects
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

#' Source Object
#'
#' @details
#' Location of the source in a supported storage service.
#'
#' @param repoSource If provided via \link{RepoSource}, get the source from this location in a Cloud Source
#' @param storageSource If provided via \link{StorageSource}, get the source from this location in Google Cloud Storage
#'
#' @return Source object
#'
#' @family Cloud Build functions
#' @export
#' @examples
#'
#' \dontrun{
#'
#' my_gcs_source <- Source(storageSource=StorageSource("gs://my-bucket","my_code.tar.gz"))
#' my_repo_source <- Source(repoSource=RepoSource("https://my-repo.com", branchName="master"))
#'
#' build1 <- cr_build("cloudbuild.yaml", source = my_gcs_source)
#' build2 <- cr_build("cloudbuild.yaml", source = my_repo_source)
#'
#' }
Source <- function(storageSource = NULL, repoSource = NULL) {

  if(!xor(is.null(repoSource),is.null(storageSource))){
    stop("Only one of repoSource or storageSource can be supplied", call. = FALSE)
  }

  if(!is.null(repoSource)){
    assert_that(is.gar_RepoSource(repoSource))
  }

  if(!is.null(storageSource)){
    assert_that(is.gar_StorageSource(storageSource))
  }
  structure(rmNullObs(list(repoSource = repoSource, storageSource = storageSource)),
            class = c("gar_Source","list"))
}

is.gar_Source <- function(x){
  inherits(x, "gar_Source")
}

is.gar_SourceStorage <- function(x){
  if(is.gar_Source(x)){
    return(!is.null(x$storageSource))
  }
  FALSE
}

is.gar_SourceRepo <- function(x){
  if(is.gar_Source(x)){
    return(!is.null(x$repoSource))
  }
  FALSE
}

#' RepoSource Object
#'
#' @details
#' Location of the source in a Google Cloud Source Repository.
#'
#' Only one of commitSha, branchName or tagName are allowed.
#'
#' @param tagName Regex matching tags to build
#' @param projectId ID of the project that owns the Cloud Source Repository
#' @param repoName Name of the Cloud Source Repository
#' @param commitSha Explicit commit SHA to build
#' @param branchName Regex matching branches to build e.g. ".*"
#' @param dir Directory, relative to the source root, in which to run the build
#'
#' @return RepoSource object
#'
#' @family Cloud Build functions
#' @export
#' @examples
#'
#' \dontrun{
#'
#' my_repo_source <- Source(repoSource=RepoSource("https://my-repo.com", branchName="master"))
#'
#' build2 <- cr_build("cloudbuild.yaml", source = my_repo_source)
#'
#' }
RepoSource <- function(repoName = NULL,
                       tagName = NULL,
                       commitSha = NULL,
                       branchName = NULL,
                       dir = NULL,
                       projectId = NULL) {

  stopifnot(!is.null(commitSha), is.null(branchName), is.null(tagName))
  stopifnot(!is.null(branchName), is.null(commitSha), is.null(tagName))
  stopifnot(!is.null(tagName), is.null(branchName), is.null(commitSha))

  structure(rmNullObs(list(tagName = tagName, projectId = projectId, repoName = repoName,
                 commitSha = commitSha, branchName = branchName, dir = dir)),
            class = c("gar_RepoSource","list"))
}

is.gar_RepoSource <- function(x){
  inherits(x, "gar_RepoSource")
}

#' StorageSource Object
#'
#' @details
#' Location of the source in an archive file in Google Cloud Storage.
#'
#' @param bucket Google Cloud Storage bucket containing the source
#' @param object Google Cloud Storage object containing the source. This object must be a gzipped archive file (.tar.gz) containing source to build.
#' @param generation Google Cloud Storage generation for the object.  If the generation is omitted, the latest generation will be used.
#'
#' @return StorageSource object
#'
#' @family Cloud Build functions
#' @export
#' @examples
#'
#' \dontrun{
#'
#'
#' my_gcs_source <- Source(storageSource=StorageSource("gs://my-bucket","my_code.tar.gz"))
#'
#' build1 <- cr_build("cloudbuild.yaml", source = my_gcs_source)
#'
#' storage <- cr_build_upload_gcs("my_folder")
#' my_gcs_source2 <- Source(storageSource=storage)
#'
#' build2 <- cr_build("cloudbuild.yaml", source = my_gcs_source2)
#'
#' }
StorageSource <- function(object = NULL, bucket = NULL, generation = NULL) {
  structure(rmNullObs(list(bucket = bucket, object = object, generation = generation)),
            class = c("gar_StorageSource","list"))
}

is.gar_StorageSource <- function(x){
  inherits(x, "gar_StorageSource")
}


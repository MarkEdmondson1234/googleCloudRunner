#' Build a source object
#'
#' @param x A \link{RepoSource} or a \link{StorageSource} object
#'
#' @export
#' @examples
#'
#' repo <- RepoSource("my_repo", branchName = "master")
#' gcs  <- StorageSource("my_code.tar.gz","gs://my-bucket")
#'
#' cr_build_source(repo)
#' cr_build_source(gcs)
#'
#' my_gcs_source <- cr_build_source(gcs)
#' my_repo_source <- cr_build_source(repo)
#'
#' \dontrun{
#'
#' build1 <- cr_build("cloudbuild.yaml", source = my_gcs_source)
#' build2 <- cr_build("cloudbuild.yaml", source = my_repo_source)
#'
#' }
#'
cr_build_source <- function(x){
  UseMethod("cr_build_source", x)
}

#' @export
#' @rdname cr_build_source
cr_build_source.gar_RepoSource <- function(x){
  Source(repoSource = x)
}

#' @export
#' @rdname cr_build_source
cr_build_source.gar_StorageSource <- function(x){
  Source(storageSource = x)
}

#' Source Object
#'
#' It is suggested to use \link{cr_build_source} instead to build sources
#'
#' @details
#' Location of the source in a supported storage service.
#'
#' @param repoSource If provided via \link{RepoSource}, get the source from
#'   this location in a Cloud Source
#' @param storageSource If provided via \link{StorageSource}, get the source
#'   from this location in Google Cloud Storage
#'
#' @return Source object
#'
#' @family Cloud Build functions
#' @export
#' @examples
#'
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' my_gcs_source <- Source(storageSource=StorageSource("my_code.tar.gz",
#'                                                     "gs://my-bucket"))
#' my_repo_source <- Source(repoSource=RepoSource("https://my-repo.com",
#'                                                branchName="master"))
#'
#' \dontrun{
#'
#' build1 <- cr_build("cloudbuild.yaml", source = my_gcs_source)
#' build2 <- cr_build("cloudbuild.yaml", source = my_repo_source)
#'
#' }
Source <- function(storageSource = NULL, repoSource = NULL) {

  if(!xor(is.null(repoSource),is.null(storageSource))){
    stop("Only one of repoSource or storageSource can be supplied",
         call. = FALSE)
  }

  if(!is.null(repoSource)){
    assert_that(is.gar_RepoSource(repoSource))
  }

  if(!is.null(storageSource)){
    assert_that(is.gar_StorageSource(storageSource))
  }
  structure(rmNullObs(list(repoSource = repoSource,
                           storageSource = storageSource)),
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
#' If you want to use GitHub or BitBucket repos, you need to setup mirroring
#'   them via Cloud Source Repositories https://source.cloud.google.com/
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
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' \dontrun{
#'
#' my_repo <- cr_build_source(
#'   RepoSource("github_markedmondson1234_googlecloudrunner",
#'              branchName="master"))
#'
#' build <- cr_build(
#'   cr_build_yaml(steps =
#'     cr_buildstep("gcloud", c("-c","ls -la"),
#'                   entrypoint = "bash",
#'                   dir = "")),
#'  source = my_repo)
#'
#' }
RepoSource <- function(repoName = NULL,
                       tagName = NULL,
                       commitSha = NULL,
                       branchName = NULL,
                       dir = NULL,
                       projectId = NULL) {

  if(!is.null(commitSha)) assert_that(is.null(branchName), is.null(tagName))
  if(!is.null(branchName)) assert_that(is.null(commitSha), is.null(tagName))
  if(!is.null(tagName)) assert_that(is.null(branchName), is.null(commitSha))

  structure(rmNullObs(list(tagName = tagName,
                           projectId = projectId,
                           repoName = repoName,
                           commitSha = commitSha,
                           branchName = branchName,
                           dir = dir)),
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
#' @param object Google Cloud Storage object containing the source. This object
#'   must be a gzipped archive file (.tar.gz) containing source to build.
#' @param generation Google Cloud Storage generation for the object.
#'   If the generation is omitted, the latest generation will be used.
#'
#' @return StorageSource object
#'
#' @family Cloud Build functions
#' @export
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' # construct Source object
#' my_gcs_source <- Source(storageSource=StorageSource("my_code.tar.gz",
#'                                                     "gs://my-bucket"))
#' build1 <- cr_build("cloudbuild.yaml", source = my_gcs_source)
#'
#' # helper that tars and adds to Source() for you
#' my_gcs_source2 <- cr_build_upload_gcs("my_folder")
#' build2 <- cr_build("cloudbuild.yaml", source = my_gcs_source2)
#'
#' }
StorageSource <- function(object, bucket = NULL, generation = NULL) {

  if(!grepl("tar\\.gz$", object)){
    stop("Object on Cloud Storage must be a *.tar.gz object.
         tar.gz a folder using cr_build_upload_gcs()", call. = FALSE)
  }

  structure(rmNullObs(list(bucket = bucket,
                           object = object,
                           generation = generation)),
            class = c("gar_StorageSource","list"))
}

is.gar_StorageSource <- function(x){
  inherits(x, "gar_StorageSource")
}

#' Create a StorageSource
#'
#' This creates a \link{StorageSource} object after uploading to Google Cloud Storage
#'
#' @param local Local directory containing the Dockerfile etc. you wish to deploy
#' @param remote The name of the folder in your bucket
#' @param bucket The Google Cloud Storage bucket to upload to
#' @param predefinedAcl The ACL rules for the object uploaded. Set to "bucketLevel" for buckets with bucket level access enabled
#' @param deploy_folder Which folder to deploy from
#'
#' @details
#'
#' It copies the files into a folder call "deploy" in your working directory,
#'   then tars it for upload
#'
#' @export
#' @importFrom googleCloudStorageR gcs_upload
#'
#' @return A Source object
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' my_gcs_source <- cr_build_upload_gcs("my_folder")
#' build1 <- cr_build("cloudbuild.yaml", source = my_gcs_source)
#'
#' }
#' @family Cloud Build functions
#' @importFrom utils tar
cr_build_upload_gcs <- function(local,
                                remote = paste0(local,
                                                format(Sys.time(), "%Y%m%d%H%M%S"),
                                                ".tar.gz"),
                                bucket = cr_bucket_get(),
                                predefinedAcl="bucketOwnerFullControl",
                                deploy_folder = "deploy"){

  if(!grepl("tar\\.gz$", remote)){
    stop("remote argument name needs to end with .tar.gz", call. = FALSE)
  }

  myMessage(paste("#Upload ", local, " to ",
                  paste0("gs://", bucket,"/",remote)),
            level = 3)

  tar_file <- paste0(basename(local), ".tar.gz")

  dir.create(deploy_folder, showWarnings = FALSE)
  myMessage(paste0("Copying files from ",
                   local, " to /", deploy_folder),
            level = 2)
  file.copy(local, deploy_folder, recursive = TRUE)
  myMessage(paste0("Compressing files from /",
                   deploy_folder, " to ", tar_file),
            level = 2)
  tar(tar_file,
      files = deploy_folder,
      compression = "gzip")

  on.exit(unlink(tar_file))
  on.exit(unlink(deploy_folder, recursive = TRUE))

  myMessage(paste("Uploading",
                  tar_file, "to", paste0(bucket,"/", remote)),
            level = 3)
  gcs_upload(tar_file, bucket = bucket, name = remote,
             predefinedAcl = predefinedAcl)



  cr_build_source(StorageSource(bucket = bucket,
                                object = remote))
}


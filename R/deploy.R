#' Deploy an R script to Cloud
#'
#' Helper to create the Dockerfile
#'
#' @param local A folder containing the R script and all its R dependencies
#' @param remote The folder on Google Cloud Storage
#' @param dockerfile An optional Dockerfile built to support the script
#' @param image_name The gcr.io image name that will be deployed and/or built
#' @param projectId The projectId where it all gets deployed to
#' @param region The Cloud Run endpoint set by CR_REGION env arg
#' @param bucket The Cloud Storage bucket that will hold the code
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'
#' cr_deploy("inst/example/", remote = "cloudrunnertest")
#'
#' }
cr_deploy <- function(local,
                      remote = basename(local),
                      dockerfile = NULL,
                      image_name = remote,
                      region = cr_region_get(),
                      bucket = Sys.getenv("GCS_DEFAULT_BUCKET"),
                      projectId = Sys.getenv("GCE_DEFAULT_PROJECT_ID")){

  local_files <- list.files(local, recursive = TRUE)
  if("Dockerfile" %in% local_files){
    dockerfile <- "Dockerfile"
  }
  # if no dockerfile, attempt to create it
  if(is.null(dockerfile)){
    # create and write a dockerfile to the folder

  } else {
    assert_that(
      is.readable(file.path(local, dockerfile))
    )
  }

  storage <- cr_build_upload_gcs(local, remote = remote, bucket = bucket)

  cr_run(make_image_name(image_name, projectId),
         source = Source(storageSource=storage),
         region = region)

}

make_image_name <- function(name, projectId){
  tolower(sprintf("gcr.io/%s/%s", projectId, name))
}

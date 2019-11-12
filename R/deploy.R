#' Deploy an R plumber script to Cloud Run
#'
#' Helper to take an R plumber script, create the Dockerfile, add the build to Cloud Build and deploy to Cloud Run
#'
#' @param local A folder containing the R script using plumber called api.R and all its dependencies
#' @param remote The folder on Google Cloud Storage
#' @param dockerfile An optional Dockerfile built to support the script.  Not needed if 'Dockerfile' exists in folder.  If supplied will be copied into deployment folder and called "Dockerfile"
#' @param image_name The gcr.io image name that will be deployed and/or built
#' @param projectId The projectId where it all gets deployed to
#' @param region The Cloud Run endpoint set by CR_REGION env arg
#' @param bucket The Cloud Storage bucket that will hold the code
#'
#' @details
#'
#' The entrypoint for CloudRun will be via a plumber script called api.R - this should be included in your local folder to deploy.
#' From that api.R you can source or call other resources in the same folder, using relative paths.
#'
#' The function will create a local folder called "deploy" and a tar.gz of that folder which is what is being uploaded to Google Cloud Storage
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'
#' cr_deploy(system.file("example/", package = "cloudRunner"))
#'
#' }
cr_deploy <- function(local,
                      remote = basename(local),
                      dockerfile = NULL,
                      image_name = remote,
                      region = cr_region_get(),
                      bucket = cr_bucket_get(),
                      projectId = cr_project_get()){

  local_files <- list.files(local, recursive = TRUE)
  if(!"api.R" %in% local_files){
    stop("Must include api.R in local deployment folder with library(plumber) implementation for Cloud Run deployments", call. = FALSE)
  }

  if("Dockerfile" %in% local_files){
    dockerfile <- "Dockerfile"
  }
  # if no dockerfile, attempt to create it
  if(is.null(dockerfile)){
    # create and write a dockerfile to the folder
    cr_dockerfile(local)

  } else {
    assert_that(
      is.readable(file.path(local, dockerfile))
    )
    file.copy(dockerfile, file.path(local, "Dockerfile"))
  }

  storage <- cr_build_upload_gcs(local, remote = remote, bucket = bucket)

  cr_run(make_image_name(image_name, projectId),
         source = Source(storageSource=storage),
         region = region)

}

make_image_name <- function(name, projectId){
  tolower(sprintf("gcr.io/%s/%s", projectId, name))
}

#' Create Dockerfile in the deployment folder
#'
#' This users \link[containerit]{dockerfile} to create a Dockerfile if possible
#'
#' @param deploy_folder The folder containing the assessts to deploy
#' @param ... Other arguments pass to \link[containerit]{dockerfile}
#'
#' @export
#'
#' @return An object of class Dockerfile
#'
#' @importFrom containerit dockerfile write print Cmd Entrypoint addInstruction<-
#' @examples
#'
#' \dontrun{
#' cr_dockerfile(system.file("example/", package = "cloudRunner"))
#' }
cr_dockerfile <- function(deploy_folder, ...){

  docker <- suppressWarnings(dockerfile(deploy_folder,
     image = "trestletech/plumber",
     offline = FALSE,
     cmd = Cmd("api.R"),
     maintainer = NULL,
     container_workdir = NULL,
     entrypoint = Entrypoint("R",
                   params = list("-e",
                                 "pr <- plumber::plumb(commandArgs()[4]); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT')))")),
     filter_baseimage_pkgs = FALSE,
     ...))

  addInstruction(docker) <-containerit:::Copy(".","./")

  write_to <- file.path(deploy_folder, "Dockerfile")
  containerit::write(docker, file = write_to)

  assert_that(
    is.readable(write_to)
  )

  myMessage("Written Dockerfile to ", write_to, level = 3)
  containerit::print(docker)
  docker

}

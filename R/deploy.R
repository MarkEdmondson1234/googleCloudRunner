#' Deploy an R plumber script to Cloud Run
#'
#' Helper to take an R plumber script, create the Dockerfile, add the build to Cloud Build and deploy to Cloud Run
#'
#' @param local A folder containing the R script using plumber called api.R and all its dependencies
#' @param remote The folder on Google Cloud Storage, and the name of the service on Cloud Run
#' @param dockerfile An optional Dockerfile built to support the script.  Not needed if 'Dockerfile' exists in folder.  If supplied will be copied into deployment folder and called "Dockerfile"
#' @param image_name The gcr.io image name that will be deployed and/or built
#' @param projectId The projectId where it all gets deployed to
#' @param region The Cloud Run endpoint set by CR_REGION env arg
#' @param bucket The Cloud Storage bucket that will hold the code
#' @inheritParams cr_buildstep_docker
#' @inheritParams cr_build
#'
#' @details
#'
#' The entrypoint for CloudRun will be via a plumber script called api.R - this should be included in your local folder to deploy.
#' From that api.R you can source or call other resources in the same folder, using relative paths.
#'
#' The function will create a local folder called "deploy" and a tar.gz of that folder which is what is being uploaded to Google Cloud Storage
#'
#' It will call \link{cr_deploy_docker} to create the image to deploy on Cloud Run
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'
#' cr_deploy_run(system.file("example/", package = "cloudRunner"))
#'
#' }
cr_deploy_run <- function(local,
                          remote = basename(local),
                          dockerfile = NULL,
                          image_name = remote,
                          tag = "$BUILD_ID",
                          region = cr_region_get(),
                          bucket = cr_bucket_get(),
                          projectId = cr_project_get(),
                          launch_browser = interactive(),
                          timeout=600L){

  task_id <- rstudio_add_job(paste("Deploy service ",remote," to CloudRun"),
                             timeout=extract_timeout(timeout))

  local_files <- list.files(local)
  if(!"api.R" %in% local_files){
    stop("Must include api.R in local deployment folder with library(plumber) implementation
         for Cloud Run deployments", call. = FALSE)
  }

  image_name <- make_image_name(image_name, projectId)

  docker_build <- cr_deploy_docker(local,
                                   image_name = image_name,
                                   dockerfile = dockerfile,
                                   remote = remote,
                                   tag = tag,
                                   bucket = bucket,
                                   projectId = projectId,
                                   launch_browser = launch_browser,
                                   timeout=timeout,
                                   task_id=task_id)

  built <- cr_build_wait(docker_build, projectId = projectId, task_id=task_id)

  cr_run(built$results$images$name,
         name = tolower(remote),
         region = region,
         projectId = projectId,
         launch_browser=launch_browser,
         timeout=timeout,
         task_id=task_id)

}

make_image_name <- function(name, projectId){
  prefix <- grepl("^gcr.io", name)
  if(prefix){
    the_image <- name
  } else {
    the_image <- sprintf("gcr.io/%s/%s", projectId, name)
  }
  tolower(the_image)
}

#' Deploy a Dockerfile so it will be built on ContainerRegistry
#'
#' If no Dockerfile present in the deployment folder, will attempt to create a Dockerfile to upload via \link{cr_dockerfile}
#'
#' @param local The folder containing the Dockerfile to build
#' @param remote The folder on Google Cloud Storage
#' @param dockerfile An optional Dockerfile built to support the script.  Not needed if 'Dockerfile' exists in folder.  If supplied will be copied into deployment folder and called "Dockerfile"
#' @param bucket The GCS bucker that will be used to deploy code source
#' @param image_name The name of the docker image to be built either full name starting with gcr.io or constructed from the image_name and projectId via \code{gcr.io/{projectId}/{image_name}}
#' @param task_id RStudio job task_id if you want to use the same task
#' @inheritParams cr_buildstep_docker
#' @inheritParams cr_build
#' @export
#' @examples
#'
#' \dontrun{
#'
#' cr_deploy_docker(system.file("example", package="cloudRunner"))
#'
#' }
cr_deploy_docker <- function(local,
                             image_name = remote,
                             dockerfile = NULL,
                             remote = basename(local),
                             tag = "$BUILD_ID",
                             timeout = 600L,
                             bucket = cr_bucket_get(),
                             projectId = cr_project_get(),
                             launch_browser = interactive(),
                             task_id=NULL){

  if(is.null(task_id)){
    task_id <- rstudio_add_job("Deploy Docker",
                               timeout=extract_timeout(timeout))
  }

  rstudio_add_output(task_id, paste("\nConfiguring Dockerfile"))
  use_or_create_dockerfile(local, dockerfile = dockerfile)

  image <- make_image_name(image_name, projectId = projectId)



  build_yaml <- Yaml(steps = cr_buildstep_docker(image,
                                                 tag = tag,
                                                 location = ".",
                                                 dir=paste0("deploy/", remote),
                                                 projectId = projectId),
                     images = image)
  rstudio_add_output(task_id,
                     paste("\n#Deploy docker build for image: \n", image))

  gcs_source <- cr_build_upload_gcs(local,
                                    remote = remote,
                                    bucket = bucket,
                                    task_id=task_id)
  cr_build(build_yaml,
           source = gcs_source,
           launch_browser = launch_browser,
           timeout=timeout)


}

use_or_create_dockerfile <- function(local, dockerfile){
  local_files <- list.files(local)
  if("Dockerfile" %in% local_files){
    return(TRUE)
  }
  # if no dockerfile, attempt to create it
  if(is.null(dockerfile)){
    # creates and write a dockerfile to the folder
    cr_dockerfile(local)

  } else {
    assert_that(
      is.readable(file.path(local, dockerfile))
    )
    myMessage("Copying Dockerfile from ", dockerfile," to ",local, level = 3)
    file.copy(dockerfile, file.path(local, "Dockerfile"))
  }
  TRUE
}


#' Create Dockerfile in the deployment folder
#'
#' This uses \link[containerit]{dockerfile} to create a Dockerfile if possible
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

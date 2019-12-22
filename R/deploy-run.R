#' Deploy html files to a nginx server on Cloud Run
#'
#' Supply the html folder to host it on Cloud Run.  Builds the dockerfile with the html within it, then deploys to Cloud Run
#'
#' @param html_folder the folder containing all the html
#' @inheritParams cr_deploy_run
#'
#' @details
#'
#' Will add a \code{default.template} file to the html folder that holds the nginx configuration
#'
#' @export
#' @import assertthat
cr_deploy_html <- function(html_folder,
                           remote = basename(html_folder),
                           image_name = remote,
                           tag = "$BUILD_ID",
                           region = cr_region_get(),
                           bucket = cr_bucket_get(),
                           projectId = cr_project_get(),
                           launch_browser = interactive(),
                           timeout=600L){

  file.copy(from = system.file("docker","nginx","default.template",
                               package = "googleCloudRunner"),
            to = file.path(html_folder, "default.template"),
            overwrite = TRUE)

  cr_deploy_run(local = html_folder,
                remote = remote,
                dockerfile = system.file("docker","nginx","Dockerfile",
                                         package = "googleCloudRunner"),
                image_name = image_name,
                tag = tag,
                region =  region,
                bucket = bucket,
                projectId = projectId,
                launch_browser = launch_browser,
                timeout=timeout)


}

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
#' @family Deployment functions
#' @details
#'
#' @section plumber scripts:
#'
#' The entrypoint for CloudRun will be via a plumber script called api.R - this should be included in your local folder to deploy.
#' From that api.R you can source or call other resources in the same folder, using relative paths.
#'
#' The function will create a local folder called "deploy" and a tar.gz of that folder which is what is being uploaded to Google Cloud Storage
#'
#' It will call \link{cr_deploy_docker} to create the image to deploy on Cloud Run
#'
#' @export
#' @examples
#'
#' \dontrun{
#'
#' cr_deploy_run(system.file("example/", package = "googleCloudRunner"))
#'
#' }
cr_deploy_plumber <- function(local,
                              remote = basename(local),
                              dockerfile = NULL,
                              image_name = remote,
                              tag = "$BUILD_ID",
                              region = cr_region_get(),
                              bucket = cr_bucket_get(),
                              projectId = cr_project_get(),
                              launch_browser = interactive(),
                              timeout=600L){

  local_files <- list.files(local)
  if(!"api.R" %in% local_files){
    stop("Must include api.R in local deployment folder
         with library(plumber) implementation
         for Cloud Run deployments", call. = FALSE)
  }

  # if no dockerfile, attempt to create it
  if(is.null(dockerfile)){
    myMessage("Creating plumber Dockerfile from ",local, level = 3)
    # creates and write a dockerfile to the folder
    cr_dockerfile_plumber(local)

  }

  cr_deploy_run(local = local,
                remote = remote,
                dockerfile = dockerfile,
                image_name = image_name,
                tag = tag,
                region =  region,
                bucket = bucket,
                projectId = projectId,
                launch_browser = launch_browser,
                timeout=timeout)

}


#' @export
#' @rdname cr_deploy_plumber
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

  assert_that(
    is.dir(local),
    is.string(remote),
    is.string(tag)
  )

  myMessage("Uploading ", local, " folder for Cloud Run", level = 3)

  image_name <- make_image_name(image_name, projectId)

  task_id <- rstudio_add_job(
    paste("Deploy service ",remote," to CloudRun"),
    timeout=extract_timeout(timeout))

  built <- cr_deploy_docker(local,
                            image_name = image_name,
                            dockerfile = dockerfile,
                            remote = remote,
                            tag = tag,
                            bucket = bucket,
                            projectId = projectId,
                            launch_browser = launch_browser,
                            timeout=timeout,
                            task_id=task_id)
  if(built$status != "SUCCESS"){
    myMessage("Error building Dockerfile", level = 3)
    rstudio_add_state(task_id, "FAILURE")
    return(built)
  }

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


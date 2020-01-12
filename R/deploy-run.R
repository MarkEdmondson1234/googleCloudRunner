#' Deploy to Cloud Run
#'
#' Deploy R api plumber scripts, HTML files or other images create the Docker image, add the build to Cloud Build and deploy to Cloud Run
#'
#' @param local A folder containing the scripts and Dockerfile to deploy to Cloud Run
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
#' These deploy containers to Cloud Run, a scale 0-to-millions container-as-a-service on Google Cloud Platform.
#'
#' @export
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_bucket_set("my-bucket")
#' cr_deploy_run(system.file("example/", package = "googleCloudRunner"))
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

  assert_that(
    is.dir(local),
    is.string(remote),
    is.string(tag)
  )

  myMessage("Uploading ", local, " folder for Cloud Run", level = 3)

  image_name <- make_image_name(image_name, projectId)

  built <- cr_deploy_docker(local,
                            image_name = image_name,
                            dockerfile = dockerfile,
                            remote = remote,
                            tag = tag,
                            bucket = bucket,
                            projectId = projectId,
                            launch_browser = launch_browser,
                            timeout=timeout)
  if(built$status != "SUCCESS"){
    myMessage("Error building Dockerfile", level = 3)
    return(built)
  }

  cr_run(built$results$images$name,
         name = lower_alpha_dash(remote),
         region = region,
         projectId = projectId,
         launch_browser=launch_browser,
         timeout=timeout)

}

#' @param html_folder the folder containing all the html
#' @inheritParams cr_deploy_run
#' @details
#'
#' @section cr_deploy_html:
#' Deploy html files to a nginx server on Cloud Run.
#'
#' Supply the html folder to host it on Cloud Run.  Builds the dockerfile with the html within it, then deploys to Cloud Run
#'
#' Will add a \code{default.template} file to the html folder that holds the nginx configuration
#'
#' @export
#' @import assertthat
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_bucket_set("my-bucket")
#'
#' cr_deploy_html("my_folder")
#'
#' }
#' @rdname cr_deploy_run
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

#' Deploy a plumber API
#' @rdname cr_deploy_run
#' @param api A folder containing the R script using plumber called api.R and all its dependencies
#'
#' @details
#'
#' @section cr_deploy_plumber:
#'
#' The entrypoint for CloudRun will be via a plumber script called api.R - this should be included in your local folder to deploy.
#' From that api.R you can source or call other resources in the same folder, using relative paths.
#'
#' The function will create a local folder called "deploy" and a tar.gz of that folder which is what is being uploaded to Google Cloud Storage
#'
#' @export
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_bucket_set("my-bucket")
#'
#' cr_deploy_plumber(system.file("example/", package = "googleCloudRunner"))
#'
#' }
cr_deploy_plumber <- function(api,
                              remote = basename(api),
                              dockerfile = NULL,
                              image_name = remote,
                              tag = "$BUILD_ID",
                              region = cr_region_get(),
                              bucket = cr_bucket_get(),
                              projectId = cr_project_get(),
                              launch_browser = interactive(),
                              timeout=600L){

  local <- api
  local_files <- list.files(local)
  if(!"api.R" %in% local_files){
    stop("Must include api.R in local deployment folder
         with library(plumber) implementation
         for Cloud Run deployments", call. = FALSE)
  }

  # if no dockerfile, attempt to create it
  if(is.null(dockerfile)){
    if(!"Dockerfile" %in% local_files){
      myMessage("No Dockerfile detected in ",local, level = 3)
      cr_dockerfile_plumber(local)
    } else {
      myMessage("Using existing Dockerfile found in folder", level = 3)
    }
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


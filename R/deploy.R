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

  task_id <- rstudio_add_job(
    paste("Deploy service ",remote," to CloudRun"),
    timeout=extract_timeout(timeout))

  local_files <- list.files(local)
  if(!"api.R" %in% local_files){
    stop("Must include api.R in local deployment folder
         with library(plumber) implementation
         for Cloud Run deployments", call. = FALSE)
  }

  image_name <- make_image_name(image_name, projectId)

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

#' Deploy a Dockerfile to be built on ContainerRegistry
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
#' cr_deploy_docker(system.file("example/", package="googleCloudRunner"))
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
  this_job <- FALSE
  if(is.null(task_id)){
    this_job <- TRUE
    task_id <- rstudio_add_job("Deploy Docker",
                               timeout=extract_timeout(timeout))
  }

  rstudio_add_output(task_id, paste("\nConfiguring Dockerfile"))
  use_or_create_dockerfile(local, dockerfile = dockerfile)

  image <- make_image_name(image_name, projectId = projectId)

  build_yaml <- cr_build_yaml(
    steps = cr_buildstep_docker(image,
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

  docker_build <- cr_build(build_yaml,
                           source = gcs_source,
                           launch_browser = launch_browser,
                           timeout=timeout)

  cr_build_wait(docker_build,
                projectId = projectId,
                task_id=task_id)
}

#' Deploy a trigger for auto-builds a pkgdown website for an R package
#'
#' This will build a pkgdown website each time the trigger fires and deploy it to git
#'
#' @inheritParams cr_buildstep_pkgdown
#' @inheritParams cr_buildtrigger
#' @param steps extra steps to run before the pkgdown website steps run
#' @param substitutions A named list of Custom Build macros that can be substituted for values in the build steps.  Will be added to an existing default substitution \code{_$GIT_REPO} which holds the git repo as deployed in \code{trigger}
#'
#' @details
#'
#' The trigger repository needs to hold an R package configured to build a pkgdown website.
#'
#' For GitHub, the repository will also need to be linked to the project you are building within, via \url{https://console.cloud.google.com/cloud-build/triggers/connect}
#'
#' The git ssh keys need to be deployed to Google KMS for the deployment of the website - see \link{cr_buildstep_git} - this only needs to be done once per Git account.  You then need to commit the encrypted ssh key (by default called \code{id_rsa.enc})
#'
#' @seealso Create your own custom deployment using \link{cr_buildstep_pkgdown} which this function uses with some defaults
#'
#' @export
#' @examples
#'
#' \dontrun{
#'
#' my_repo <- GitHubEventsConfig("MarkEdmondson1234/googleAnalyticsR")
#' cr_deploy_pkgdown(my_repo)
#'
#' }
cr_deploy_pkgdown <- function(trigger,
                              steps = NULL,
                              git_email = "googlecloudrunner@r.com",
                              keyring = "my-keyring",
                              key = "github-key",
                              env = NULL,
                              substitutions = NULL,
                              cipher = "id_rsa.enc",
                              build_image = 'gcr.io/gcer-public/packagetools:master'){

  github_repo <- extract_repo(trigger)

  build_yaml <-
    cr_build_yaml(steps = c(steps,
                   cr_buildstep_pkgdown("$_GIT_REPO",
                                      git_email = git_email,
                                      env = env))
         )

  build <- cr_build_make(build_yaml)

  pkgdown_name <- paste0("pkgdown-deploy-", tolower(basename(github_repo)))
  trigger <- cr_buildtrigger(pkgdown_name,
                             trigger = trigger,
                             build = build,
                             description = pkgdown_name,
                             substitutions = c(list(`_GIT_REPO` = github_repo),
                                               substitutions))
  myMessage(paste("pkgdown trigger deployed for repo:", github_repo,
                  "- ensure git ssh key is on KMS and ", cipher,
                  "is checked into the repository - after which the website will be built on each commit"),
            level = 3)
  trigger

}

extract_repo <- function(x){
  if(is.gar_RepoSource(x)){
    return(x$repoName)
  } else if(is.gar_GitHubEventsConfig(x)){
    return(paste0(x$owner,"/",x$name))
  } else {
    stop("Could not find repo from object of class ", class(x), call. = FALSE)
  }
}

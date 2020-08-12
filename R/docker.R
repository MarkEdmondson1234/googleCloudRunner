#' Deploy Docker build from a Git repo
#'
#' This helps the common use case of building a Dockerfile based on the contents of a GitHub repo, and sets up a build trigger so it will build on every commit.
#'
#' @seealso \link{cr_deploy_docker} which lets you build Dockerfiles for more generic use cases
#'
#' @param repo The git repo holding the Dockerfile from \link{cr_buildtrigger_repo}
#' @param image The name of the image you want to build
#' @param image_tag What to tag the build docker image
#' @param trigger_name The trigger name
#' @param ... Other arguments passed to `cr_buildstep_docker`
#' @inheritDotParams cr_buildstep_docker
#' @inheritParams cr_buildtrigger
#' @param projectId The project to build under
#' @inheritParams cr_build_make
#' @family Deployment functions
#' @details
#'
#' This creates a buildtrigger to do a kamiko cache enabled Docker build upon each commit, as defined by your repo settings via \link{cr_buildtrigger_repo}.  It will build all tags concurrently.
#'
#' @export
#' @examples
#'
#' \dontrun{
#' repo <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner")
#' cr_deploy_docker_trigger(repo, "test", dir = "cloud_build")
#' }
cr_deploy_docker_trigger <- function(repo,
                                     image,
                                     trigger_name = paste0("docker-", image),
                                     image_tag = c("latest","$SHORT_SHA","$BRANCH_NAME"),
                                     ...,
                                     substitutions = NULL,
                                     ignoredFiles = NULL,
                                     includedFiles = NULL,
                                     timeout = NULL,
                                     projectId = cr_project_get()){

  build_docker <- cr_build_make(
    cr_build_yaml(
      steps = cr_buildstep_docker(image,
                                  tag = image_tag,
                                  ...,
                                  kaniko_cache = TRUE)
    ),
    timeout = timeout)

  safe_name <- gsub("[^a-zA-Z1-9]","-", trigger_name)
  cr_buildtrigger(build_docker,
                  name = safe_name,
                  trigger = repo,
                  description = paste0(safe_name,Sys.time()),
                  trigger_tags = "docker-build",
                  substitutions = substitutions,
                  ignoredFiles = ignoredFiles,
                  includedFiles = includedFiles)
}


#' Deploy a local Dockerfile to be built on ContainerRegistry
#'
#' Build a local Dockerfile in the cloud. See googleCloudRunner website for help how to generate Dockerfiles.  If you want the docker to build on each commit, see also \link{cr_deploy_docker_trigger}
#'
#'
#' @seealso If you want the docker to build on each commit, see \link{cr_deploy_docker_trigger}
#'
#' @param local The folder containing the Dockerfile to build
#' @param remote The folder on Google Cloud Storage
#' @param dockerfile An optional Dockerfile built to support the script.  Not needed if 'Dockerfile' exists in folder.  If supplied will be copied into deployment folder and called "Dockerfile"
#' @param bucket The GCS bucket that will be used to deploy code source
#' @param image_name The name of the docker image to be built either full name starting with gcr.io or constructed from the image_name and projectId via \code{gcr.io/{projectId}/{image_name}}
#' @param predefinedAcl Access setting for the bucket used in deployed.  Set to "bucketLevel" if using bucket level access
#' @param ... Other arguments passed to \link{cr_buildstep_docker}
#' @inheritParams cr_buildstep_docker
#' @inheritParams cr_build
#' @inheritDotParams cr_buildstep_docker
#' @export
#' @family Deployment functions
#'
#' @details
#'
#' This lets you deploy local folders with Dockerfiles, automating saving the source on Google Cloud Storage.
#'
#' To deploy builds on git triggers and sources such as GitHub, see the examples of \link{cr_buildstep_docker} or the use cases on the website
#'
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' cr_email_set("123456@projectid.iam.gserviceaccount.com")
#' cr_bucket_set("my-bucket")
#'
#' b <- cr_deploy_docker(system.file("example/", package="googleCloudRunner"))
#'
#' }
cr_deploy_docker <- function(local,
                             image_name = remote,
                             dockerfile = NULL,
                             remote = basename(local),
                             tag = c("latest","$BUILD_ID"),
                             timeout = 600L,
                             bucket = cr_bucket_get(),
                             projectId = cr_project_get(),
                             launch_browser = interactive(),
                             kaniko_cache=TRUE,
                             predefinedAcl="bucketOwnerFullControl",
                             ...){
  assert_that(
    dir.exists(local)
  )

  myMessage("Building", local, "folder for Docker image: ",
            image_name, level = 2)

  myMessage(paste("Configuring Dockerfile"), level = 2)
  find_dockerfile(local, dockerfile = dockerfile)

  assert_that(
    is.readable(file.path(local, "Dockerfile"))
  )

  image <- make_image_name(image_name, projectId = projectId)

  #kaniko_cache will push image for you
  if(kaniko_cache){
    push_image <- NULL
  } else {
    push_image <- image
  }

  build_yaml <- cr_build_yaml(
    steps = cr_buildstep_docker(image,
                                tag = tag,
                                location = ".",
                                dir=paste0("deploy/", basename(local)),
                                projectId = projectId,
                                kaniko_cache = kaniko_cache,
                                waitFor = "-", # build concurrent tags
                                ...),
    images = push_image)

  image_tag <- paste0(image, ":", tag)
  myMessage("#Deploy docker build for image: ", image, level = 3)

  remote_tar <- remote
  if(!grepl("tar\\.gz$", remote)){
    remote_tar <- paste0(remote, ".tar.gz")
  }
  gcs_source <- cr_build_upload_gcs(local,
                                    remote = remote_tar,
                                    bucket = bucket,
                                    predefinedAcl=predefinedAcl)

  docker_build <- cr_build(build_yaml,
                           source = gcs_source,
                           launch_browser = launch_browser,
                           timeout=timeout)

  b <- cr_build_wait(docker_build, projectId = projectId)

  myMessage(image_tag, level = 3)

  # to make it the same as non-kaniko docker builds
  if(kaniko_cache){
    b$results$images$name <- b$steps$args[[1]][[4]]
  }

  b
}





#' Create a build step to build and push a docker image
#'
#' @param image The image tag that will be pushed, starting with gcr.io or created by combining with \code{projectId} if not starting with gcr.io
#' @param tag The tag or tags to be attached to the pushed image - can use \code{Build} macros
#' @param location Where the Dockerfile to build is in relation to \code{dir}
#' @param ... Further arguments passed in to \link{cr_buildstep}
#' @param projectId The projectId
#' @param dockerfile Specify the name of the Dockerfile found at \code{location}
#' @param kaniko_cache If TRUE will use kaniko cache for Docker builds.
#'
#' @details
#'
#' Setting \code{kaniko_cache = TRUE} will enable caching of the layers of the Dockerfile, which will speed up subsequent builds of that Dockerfile.  See \href{https://cloud.google.com/cloud-build/docs/kaniko-cache}{Using Kaniko cache}
#'
#' If building multiple tags they don't have to run sequentially - set \code{waitFor = "-"} to build concurrently
#'
#' @family Cloud Buildsteps
#' @export
#' @import assertthat
#' @examples
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#'
#' cr_buildstep_docker("gcr.io/my-project/my-image")
#' cr_buildstep_docker("my-image")
#' cr_buildstep_docker("my-image", tag = "$BRANCH_NAME")
#'
#' # setting up a build to trigger off a Git source:
#' my_image <- "gcr.io/my-project/my-image"
#' my_repo <- RepoSource("github_markedmondson1234_googlecloudrunner",
#'                       branchName="master")
#' \dontrun{
#' docker_yaml <- cr_build_yaml(steps = cr_buildstep_docker(my_image))
#' built_docker <- cr_build(docker_yaml, source = my_repo)
#'
#' # make a build trigger so it builds on each push to master
#' cr_buildtrigger("build-docker", trigger = my_repo, build = built_docker)
#'
#'
#' # add a cache to your docker build to speed up repeat builds
#' cr_buildstep_docker("my-image", kaniko_cache = TRUE)
#'
#' # building using manual buildsteps to clone from git
#' bs <- c(
#'   cr_buildstep_gitsetup("github-ssh"),
#'   cr_buildstep_git(c("clone","git@github.com:MarkEdmondson1234/googleCloudRunner",".")),
#'   cr_buildstep_docker("gcr.io/gcer-public/packagetools",
#'                       dir = "inst/docker/packages/")
#'   )
#'
#' built <- cr_build(cr_build_yaml(bs))
#' }
cr_buildstep_docker <- function(image,
                                tag = c("latest","$BUILD_ID"),
                                location = ".",
                                projectId = cr_project_get(),
                                dockerfile = "Dockerfile",
                                kaniko_cache = FALSE,
                                ...){
  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$name),
    is.null(dots$args),
    is.null(dots$prefix),
    is.null(dots$entrypoint),
    is.null(dots$id)
  )

  prefix <- grepl("^gcr.io", image)
  if(prefix){
    the_image <- image
  } else {
    the_image <- paste0("gcr.io/", projectId, "/", image)
  }

  myMessage("Image to be built: ", the_image, level = 2)

  the_image_tagged <- c(vapply(tag,
                               function(x) c("--tag", paste0(the_image, ":", x)),
                               character(2),
                               USE.NAMES = FALSE)
  )

  if(!kaniko_cache){
    return(c(
      cr_buildstep("docker",
                   c("build",
                     "-f", dockerfile,
                     the_image_tagged,
                     location),
                   ...),
      cr_buildstep("docker", c("push", the_image), ...)
    ))
  }

  # kaniko cache
  build_context <- "dir:///workspace/"

  if(!is.null(dots$dir)){
    build_context <- paste0(build_context, dots$dir)
  }

  if(location != "."){
    build_context <- paste0(build_context, "/", location)
  }

  vapply(tag,
         function(x){
           cr_buildstep(
             name = "gcr.io/kaniko-project/executor:latest",
             args = c(
               "-f",dockerfile,
               "--destination", paste0(the_image,":",x),
               sprintf("--context=%s", build_context),
               "--cache=true"
             ),
             ...)
         },
         FUN.VALUE = list(length(tag)),
         USE.NAMES = FALSE)


}


#' Create Dockerfile in the deployment folder
#'
#' This did call containerit but its not on CRAN so removed
#'
#' @noRd
#'
#' @param deploy_folder The folder containing the assessts to deploy
#' @param ... Other arguments pass to containerit::dockerfile
#'
#'
#' @return An object of class Dockerfile
#'
#' @examples
#'
#' \dontrun{
#' cr_dockerfile_plumber(system.file("example/", package = "googleCloudRunner"))
#' }
cr_dockerfile_plumber <- function(deploy_folder, ...){
  stop(
    "No Dockerfile detected.  Please create one in the deployment folder.  See a guide on website on how to use library(containerit) to do so: https://code.markedmondson.me/googleCloudRunner/articles/cloudrun.html#creating-a-dockerfile-with-containerit"
    , call. = FALSE)
}

find_dockerfile <- function(local, dockerfile){

  local_files <- list.files(local)
  if("Dockerfile" %in% local_files){
    myMessage("Dockerfile found in ",local, level = 3)
    return(TRUE)
  }

  # if no dockerfile, attempt to create it
  assert_that(is.readable(dockerfile))

  myMessage("Copying Dockerfile from ", dockerfile," to ",local, level = 3)
  file.copy(dockerfile, file.path(local, "Dockerfile"))

  TRUE
}


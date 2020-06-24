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
  dots <- list(...)
  if(!is.null(dots$dir)){
    build_context <- paste0(build_context, dots$dir)
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


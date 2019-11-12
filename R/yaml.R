#' Helper to create yaml files
#'
#' @param ... steps in the yaml object
#'
#' @export
#' @family Cloud Build functions, yaml functions
#' @examples
#'
#'Yaml(steps = list(
#'       cr_build_step("docker", "version"),
#'       cr_build_step("gcloud", "version")),
#'     images = "gcr.io/my-project/my-image")
Yaml <- function(...){
  structure(
    list(...),
    class = c("cr_yaml","list")
  )
}

#' Create a yaml build step
#'
#' Helper for creating build steps for upload to Cloud Build
#'
#' @param name name of SDK appended to stem
#' @param args character vector of arguments
#' @param stem prefixed to name
#' @param entrypoint change the entrypoint for the docker container
#' @param dir The directory to use, relative to /workspace e.g. /workspace/deploy/
#' @param id Optional id for the step
#'
#' @details
#' By default dir is set to /deploy to air deployment from GCS, but you may want to set this to "" when using \link{RepoSource}
#'
#' @export
#' @family Cloud Build functions, yaml functions
#' @examples
#'
#' # creating yaml for use in deploying cloud run
#' image = "gcr.io/my-project/my-image$BUILD_ID"
#' run_yaml <- Yaml(
#'     steps = list(
#'          cr_build_step("docker", c("build","-t",image,".")),
#'          cr_build_step("docker", c("push",image)),
#'          cr_build_step("gcloud", c("beta","run","deploy", "test1",
#'                                    "--image", image))),
#'     images = image)
#'
#' # list files with a new entrypoint for gcloud
#' Yaml(steps = cr_build_step("gcloud", c("-c","ls -la"), entrypoint = "bash"))
#'
cr_build_step <- function(name,
                          args,
                          id = NULL,
                          stem = "gcr.io/cloud-builders/",
                          entrypoint = NULL,
                          dir = "deploy"){
  rmNullObs(list(
    name = paste0(stem, name),
    entrypoint = entrypoint,
    args = args,
    id = id,
    dir = dir
  ))
}

is.Yaml <- function(x){
  inherits(x, "cr_yaml")
}

#' @import assertthat
#' @importFrom yaml read_yaml
#' @noRd
get_cr_yaml <- function(x){
  if(is.Yaml(x)){
    return(x)
  }
  # its a yaml file
  assert_that(
    is.readable(x),
    grepl("\\.ya?ml$", x, ignore.case = TRUE)
  )

  read_yaml(x)
}
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


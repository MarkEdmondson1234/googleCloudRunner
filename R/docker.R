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
#' @examples
#'
#' \dontrun{
#' cr_dockerfile(system.file("example/", package = "googleCloudRunner"))
#' }
cr_dockerfile <- function(deploy_folder, ...){
  check_package_installed("containerit")
  docker <- suppressWarnings(
    containerit::dockerfile(
      deploy_folder,
      image = "trestletech/plumber",
      offline = FALSE,
      cmd = containerit::Cmd("api.R"),
      maintainer = NULL,
      container_workdir = NULL,
      entrypoint = containerit::Entrypoint("R",
                       params = list("-e",
                                     "pr <- plumber::plumb(commandArgs()[4]); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT')))")),
      filter_baseimage_pkgs = FALSE,
      ...))

  containerit::addInstruction(docker) <-containerit:::Copy(".","./")

  write_to <- file.path(deploy_folder, "Dockerfile")
  containerit::write(docker, file = write_to)

  assert_that(
    is.readable(write_to)
  )

  myMessage("Written Dockerfile to ", write_to, level = 3)
  containerit::print(docker)
  docker

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


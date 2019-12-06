#' Helper to create yaml files
#'
#' @param ... steps in the yaml object
#'
#' @export
#' @family Cloud Build functions, yaml functions
#' @examples
#'
#'Yaml(steps = c(
#'       cr_buildstep("docker", "version"),
#'       cr_buildstep("gcloud", "version")),
#'     images = "gcr.io/my-project/my-image")
Yaml <- function(...){
  structure(
    list(...),
    class = c("cr_yaml","list")
  )
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
  } else if(assertthat::is.string(x)){
    # its a yaml file
    assert_that(
      is.readable(x),
      grepl("\\.ya?ml$", x, ignore.case = TRUE)
    )
  } else {
    stop("Yaml is not class(yaml) or a filepath - class:", class(x))
  }

  read_yaml(x)
}

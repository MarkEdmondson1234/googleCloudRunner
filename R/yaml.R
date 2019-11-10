#' @export
#' @noRd
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
  }
  # its a yaml file
  assert_that(
    is.readable(x),
    grepl("\\.ya?ml$", x, ignore.case = TRUE)
  )

  read_yaml(x)
}
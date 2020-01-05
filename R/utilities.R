string_to_list <- function(x){
  if(assertthat::is.string(x)){
    return(list(x))
  }
  x
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

make_image_name <- function(name, projectId){
  prefix <- grepl("^gcr.io", name)
  if(prefix){
    the_image <- name
  } else {
    the_image <- sprintf("gcr.io/%s/%s", projectId, name)
  }
  tolower(the_image)
}

lower_alpha_dash <- function(x){
  gsub("[^-a-zA-Z1-9]","-", x)
}


safe_set <- function(x, set, to){
  if(!is.null(x[[set]]) && x[[set]] != to) x[[set]] <- to
  x
}

#' check package installed
#' @noRd
check_package_installed <- function(y){
  if (!requireNamespace(y, quietly = TRUE)){
      nope <- sprintf("%s needed for this function to work. Please install it and try this function again.",
                      y,y)
      stop(nope, call. = FALSE)
  }
  TRUE
}


#' Custom message log level
#'
#' @param ... The message(s)
#' @param level The severity
#'
#' @details 0 = everything, 1 = debug, 2=normal, 3=important
#' @keywords internal
#' @noRd
myMessage <- function(..., level = 2){

  compare_level <- getOption("googleAuthR.verbose")

  if(level >= compare_level){
    message(Sys.time() ,"> ", ...)
  }

}

#' A helper function that tests whether an object is either NULL _or_
#' a list of NULLs
#'
#' @keywords internal
#' @noRd
is.NullOb <- function(x) is.null(x) | all(sapply(x, is.null))

#' Recursively step down into list, removing all such objects
#'
#' @keywords internal
#' @noRd
rmNullObs <- function(x) {
  x <- Filter(Negate(is.NullOb), x)
  lapply(x, function(x) if (is.list(x)) rmNullObs(x) else x)
}

#' if argument is NULL, no line output
#' @noRd
cat0 <- function(prefix = "", x){
  if(!is.null(x)){
    cat(prefix, x, "\n")
  }
}

#' Timestamp to R date
#' @keywords internal
#' @noRd
timestamp_to_r <- function(t){
  as.POSIXct(t, format = "%Y-%m-%dT%H:%M:%S", tz="UTC")
}

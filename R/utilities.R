underscore_to_dash <- function(x){
  gsub("[^a-zA-Z0-9\\-]", "-", x)
}


#' If x is NULL and the_list$x is not NULL, x <- the_list$x
#' @noRd
#' @keywords internal
override_list <- function(x, the_list){
  if (is.null(x) && !is.null(the_list[[deparse(substitute(x))]])) {
    x <- the_list[[deparse(substitute(x))]]
  }
  x
}

# unique per invocation, not per session like tempdir()
tempdir_unique <- function() {
  dd <- tempfile()
  dir.create(dd)
  dd
}


string_to_list <- function(x) {
  if (assertthat::is.string(x)) {
    return(list(x))
  }
  x
}

extract_repo <- function(x) {
  if (is.gar_RepoSource(x)) {
    return(x$repoName)
  } else if (is.gar_GitHubEventsConfig(x)) {
    return(paste0(x$owner, "/", x$name))
  } else {
    stop("Could not find repo from object of class ", class(x), call. = FALSE)
  }
}

has_registry_prefix <- function(name) {
  grepl("^(eu|asia|us|)([.]|)gcr.io", name) ||
    grepl("^.*-docker.pkg.dev", name)
}

make_image_name <- function(name, projectId) {
  prefix <- has_registry_prefix(name)
  if (prefix) {
    the_image <- name
  } else {
    the_image <- sprintf("gcr.io/%s/%s", projectId, name)
  }
  tolower(the_image)
}

lower_alpha_dash <- function(x) {
  gsub("[^-a-zA-Z0-9]", "-", x)
}


safe_set <- function(x, set, to) {
  if (!is.null(x[[set]]) && x[[set]] != to) x[[set]] <- to
  x
}

#' check package installed
#' @noRd
check_package_installed <- function(y) {
  if (!requireNamespace(y, quietly = TRUE)) {
    nope <- sprintf(
      "%s needed for this function to work. Please install it and try this function again.",
      y, y
    )
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
#' @import cli
myMessage <- function(..., level = 2) {
  compare_level <- getOption("googleAuthR.verbose")

  if (level >= compare_level) {
    time <- paste(Sys.time(), ">") #nolint
    mm <- paste(...)
    if (grepl("^#", mm[[1]])) {
      cli::cli_h1(mm)
    } else {
      cli::cli_div(theme = list(span.time = list(color = "grey")))
      cli::cli_alert_info("{.time {time}} {mm}")
      cli::cli_end()
    }
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
cat0 <- function(prefix = "", x) {
  if (!is.null(x)) {
    cat(prefix, x, "\n")
  }
}

#' Timestamp to R date
#' @keywords internal
#' @noRd
timestamp_to_r <- function(t) {
  if (is.null(t)) {
    return(t)
  }
  tryCatch(
    as.POSIXct(t, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
    error = function(err) {
      warning(err$message, " t=", t)
      return(t)
    }
  )
}

#' difftime formatting
#' @keywords internal
#' @noRd
#' @seealso https://stackoverflow.com/questions/51236962/how-to-format-a-difftime-object-to-a-string-with-hhmmss
difftime_format <- function(start, end){
  stopifnot(inherits(start, "POSIXct"),
            inherits(end, "POSIXct"))
  duration <- difftime(end, start, units = "secs")
  x <- abs(as.numeric(duration))

  if(x < 60){
    sprintf("%02ds", x %% 60 %/% 1)
  } else if (x < 3600) {
    sprintf("%02dm%02ds",
            x %% 3600 %/% 60,
            x %% 60 %/% 1)
  } else {
    sprintf("%02dh%02dm%02ds",
            x %% 86400 %/% 3600,
            x %% 3600 %/% 60,
            x %% 60 %/% 1)
  }

}

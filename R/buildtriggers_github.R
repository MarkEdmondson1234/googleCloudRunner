#' GitHubEventsConfig Object
#'
#' @param event Whether to trigger on push or pull GitHub events
#' @param branch Regex of branches to match
#' @param x The repository in format {owner}/{repo} e.g. MarkEdmondson1234/googleCloudRunner
#' @param commentControl If a pull request, whether to require comments before builds are triggered.
#' @param tag If a push request, regexes matching what tags to build. If not \code{NULL} then argument \code{branch} will be ignored
#'
#' @details
#'
#' The syntax of the regular expressions accepted is the syntax accepted by RE2 and described at \url{https://github.com/google/re2/wiki/Syntax}
#'
#' @return GitHubEventsConfig object
#'
#' @family BuildTrigger functions
#' @import assertthat
#' @export
GitHubEventsConfig <- function(x,
                               event = c("push", "pull"),
                               branch = ".*",
                               tag = NULL,
                               commentControl = c("COMMENTS_DISABLED",
                                                  "COMMENTS_ENABLED")) {

  repo <- split_github(x)

  event <- match.arg(event)
  commentControl <- match.arg(commentControl)
  pullRequest <- NULL
  push <- NULL

  if(!is.null(tag)){
    branch <- NULL
  }

  if(event == "pull"){
    pullRequest <- list(branch = branch, commentControl = commentControl)
  } else if(event == "push"){
    push <- list(branch = branch, tag = tag)
  }

  assert_that(xor(is.null(pullRequest), is.null(push)),
              xor(is.null(branch), is.null(tag)))

  structure(rmNullObs(list(pullRequest = pullRequest,
                           push = push,
                           owner = repo$owner,
                           name = repo$name)),
            class = c("GitHubEventsConfig","list"))
}

is.gar_GitHubEventsConfig <- function(x){
  inherits(x, "GitHubEventsConfig")
}

split_github <- function(x){
  o <- list(owner = dirname(x), name = basename(x))
  assert_that(o$owner != "", o$name != "")
  o
}

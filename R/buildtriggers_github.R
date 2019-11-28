#' GitHubEventsConfig Object
#'
#' @param event Whether to trigger on push or pull GitHub events
#' @param branch Regex of branches to match
#' @param owner Owner of the repository e.g. MarkEdmondson1234
#' @param name Name of the repository e.g. googleCloudRunner
#' @param commentControl If a pull request, whether to require comments before builds are triggered.
#' @param tag If a push request, regexes matching what tags to build.
#'
#' @details
#'
#' The syntax of the regular expressions accepted is the syntax accepted by RE2 and described at \url{https://github.com/google/re2/wiki/Syntax}
#'
#' @return GitHubEventsConfig object
#'
#' @family BuildTrigger functions
#' @export
GitHubEventsConfig <- function(owner,
                               name,
                               event = c("push", "pull"),
                               branch = ".*",
                               tag = ".*",
                               commentControl = c("COMMENTS_DISABLED",
                                                  "COMMENTS_ENABLED")) {

  event <- match.arg(event)
  commentControl <- match.arg(commentControl)
  pullRequest <- NULL
  push <- NULL

  if(event == "push"){
    pullRequest <- list(branch = branch, commentControl = commentControl)
  } else if(event == "pull"){
    push <- list(branch = branch, tag = tag)
  }

  assert_that(xor(is.null(pullRequest), is.null(push)))

  structure(rmNullObs(list(pullRequest = pullRequest,
                           push = push,
                           owner = owner,
                           name = name)),
            class = c("GitHubEventsConfig","list"))
}

is.gar_GitHubEventsConfig <- function(x){
  inherits(x, "GitHubEventsConfig")
}

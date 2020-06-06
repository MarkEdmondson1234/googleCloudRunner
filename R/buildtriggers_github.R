#' Create a buildtrigger repo object
#'
#' Create a repository trigger object for use in build triggers
#'
#' @param repo_name Either the GitHub username/repo_name or the Cloud Source repo_name
#' @param branch Regex of the branches that will trigger a build.  Ignore if tag is not NULL
#' @param tag Regex of tags that will trigger a build
#' @param type Whether trigger is GitHub or Cloud Source repoistory
#' @param github_secret If you need to pull from a private GitHub repo, add the github secret from Google Secret Manager which will be used via \link{cr_buildstep_secret}
#' @param ... Other arguments passed to either \link{GitHubEventsConfig} or \link{RepoSource}
#'
#' @family BuildTrigger functions
#' @export
#' @import assertthat
cr_buildtrigger_repo <- function(repo_name,
                                 branch = ".*",
                                 tag = NULL,
                                 type = c("github","cloud_source"),
                                 github_secret = NULL,
                                 ...){

  assert_that(is.string(repo_name),
              is.string(branch))
  type <- match.arg(type)
  dots <- list(...)

  if(type == "github"){

    repo <- GitHubEventsConfig(repo_name,
                               branch = branch,
                               tag = NULL,
                               ...)
  } else if(type == "cloud_source"){

    if(is.null(dots$projectId)){
      projectId <- cr_project_get()
    } else {
      projectId <- dots$projectId
    }

    repo <- RepoSource(repo_name,
                       branchName = branch,
                       tagName = tag,
                       projectId = projectId,
                       ...)

  }

  structure(list(repo = repo,
                 github_secret = github_secret,
                 type = type),
            class = c("cr_buildtrigger_repo","list"))

}

is.buildtrigger_repo <- function(x){
  inherits(x, "cr_buildtrigger_repo")
}


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

#' Create a buildtrigger pub/sub object
#'
#' Create a trigger from a Pub/Sub topic
#'
#' @inheritParams PubsubConfig
#' @param topic The name of the Cloud Pub/Sub topic or a Topic object from \link[googlePubsubR]{topics_get}
#' @param projectId The GCP project the topic is created within
#' @family BuildTrigger functions
#' @export
#'
#' @details
#'
#' When using a PubSub trigger, you can use data within your PubSub message in substitution variables within the build.  The data from pubsub is available in the variable value: \code{$(body.message.data.x)} when x is a field in the pubsub message.
#'
#' @examples
#'
#' # create build object
#' cloudbuild <- system.file("cloudbuild/cloudbuild_substitutions.yml",
#'   package = "googleCloudRunner"
#' )
#' the_build <- cr_build_make(cloudbuild)
#'
#' # this build includes substitution variables that read from pubsub message var1
#' the_build
#'
#' # using googlePubSubR to create pub/sub topic if needed
#' \dontrun{
#' library(googlePubsubR)
#' pubsub_auth()
#' topics_create("test-topic")
#' }
#'
#' # create build trigger that will work from pub/subscription
#' pubsub_trigger <- cr_buildtrigger_pubsub("test-topic")
#' pubsub_trigger
#' \dontrun{
#' cr_buildtrigger(the_build, name = "pubsub-triggered-subs", trigger = pubsub_trigger)
#' }
#'
#' # make base64 encoded json for pubsub
#' library(jsonlite)
#' library(googlePubsubR)
#'
#' # the message with the var1 that will be passed into the Cloud Build via substitution
#' message <- toJSON(list(var1 = "hello mum"))
#'
#' # turning into JSON and encoding
#' send_me <- msg_encode(message)
#' \dontrun{
#' # send a PubSub message with the encoded data message
#' topics_publish(PubsubMessage(send_me), "test-topic")
#'
#' # did it work? After a while should see logs if it did
#' cr_buildtrigger_logs("pubsub-triggered-subs")
#' }
#'
cr_buildtrigger_pubsub <- function(topic,
                                   serviceAccountEmail = NULL,
                                   projectId = cr_project_get()) {

  if(inherits(topic, "Topic")){
    topic <- topic$name
  }

  assert_that(
    is.string(topic)
  )

  if (grepl("^projects", topic)) {
    topic_name <- topic
  } else {
    topic_name <- sprintf("projects/%s/topics/%s", projectId, topic)
  }

  PubsubConfig(
    topic = topic_name,
    serviceAccountEmail = serviceAccountEmail
  )
}

#' Create a buildtrigger webhook object
#'
#' Create a trigger from a webhook
#'
#'
#' @inheritParams WebhookConfig
#' @family BuildTrigger functions
#' @export
cr_buildtrigger_webhook <- function(secret) {
  WebhookConfig(secret)
}


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
                                 type = c("github", "cloud_source"),
                                 github_secret = NULL,
                                 ...) {
  assert_that(
    is.string(repo_name)
  )
  type <- match.arg(type)
  dots <- list(...)

  if(!is.null(tag) && !is.null(branch)){
    stop("Must only have one of branch or tag - set branch=NULL if using tag",
         call. = FALSE)
  }

  if (type == "github") {
    repo <- GitHubEventsConfig(repo_name,
      branch = branch,
      tag = tag,
      ...
    )
  } else if (type == "cloud_source") {
    if (is.null(dots$projectId)) {
      projectId <- cr_project_get()
    } else {
      projectId <- dots$projectId
    }

    repo <- RepoSource(repo_name,
      branchName = branch,
      tagName = tag,
      ...
    )
  }

  structure(list(
    repo = repo,
    github_secret = github_secret,
    type = type
  ),
  class = c("cr_buildtrigger_repo", "list")
  )
}

is.buildtrigger_repo <- function(x) {
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
                               commentControl = c(
                                 "COMMENTS_DISABLED",
                                 "COMMENTS_ENABLED"
                               )) {
  repo <- split_github(x)

  event <- match.arg(event)
  commentControl <- match.arg(commentControl)
  pullRequest <- NULL
  push <- NULL

  if (!is.null(tag)) {
    branch <- NULL
  }

  if (event == "pull") {
    pullRequest <- list(branch = branch, commentControl = commentControl)
  } else if (event == "push") {
    push <- list(branch = branch, tag = tag)
  }

  assert_that(
    xor(is.null(pullRequest), is.null(push)),
    xor(is.null(branch), is.null(tag))
  )

  structure(rmNullObs(list(
    pullRequest = pullRequest,
    push = push,
    owner = repo$owner,
    name = repo$name
  )),
  class = c("GitHubEventsConfig", "list")
  )
}

is.gar_GitHubEventsConfig <- function(x) {
  inherits(x, "GitHubEventsConfig")
}

split_github <- function(x) {
  o <- list(owner = dirname(x), name = basename(x))
  assert_that(o$owner != "", o$name != "")
  o
}

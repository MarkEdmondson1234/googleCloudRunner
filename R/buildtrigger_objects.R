#' BuildTrigger Object
#'
#' Configuration for an automated build in response to source repositorychanges.
#'
#' @param substitutions A named list of Build macro variables
#' @param filename Path, from the source root, to a file whose contents is used for the build
#' @param name User assigned name of the trigger
#' @param tags Tags for annotation of a `BuildTrigger`
#' @param build Contents of the build template
#' @param ignoredFiles ignored_files and included_files are file glob matches extended with support for "**".
#' @param github a \link{GitHubEventsConfig} object - mutually exclusive with \code{triggerTemplate}
#' @param includedFiles If any of the files altered in the commit pass the ignored_files
#' @param disabled If true, the trigger will never result in a build
#' @param sourceToBuild A \link{cr_buildtrigger_repo} object.  This field is currently only used by Webhook, Pub/Sub, Manual, and Cron triggers and is the source of the build will execute upon.
#' @param triggerTemplate a \link{RepoSource} object - mutually exclusive with \code{github}
#' @param description Human-readable description of this trigger
#' @param pubsubConfig PubsubConfig describes the configuration of a trigger that creates a build whenever a Pub/Sub message is published.
#' @param webhookConfig WebhookConfig describes the configuration of a trigger that creates a build whenever a webhook is sent to a trigger's webhook URL.
#'
#' @seealso \url{https://cloud.google.com/build/docs/api/reference/rest/v1/projects.triggers}
#'
#' @return BuildTrigger object
#'
#' @family BuildTrigger functions
#' @export
BuildTrigger <- function(filename = NULL,
                         name = NULL,
                         tags = NULL,
                         build = NULL,
                         ignoredFiles = NULL,
                         github = NULL,
                         substitutions = NULL,
                         includedFiles = NULL,
                         disabled = NULL,
                         sourceToBuild = NULL,
                         triggerTemplate = NULL,
                         webhookConfig = NULL,
                         description = NULL,
                         pubsubConfig = NULL) {
  assert_that(
    xor(is.null(build), is.null(filename)),
    !is.null(webhookConfig) ||
      !is.null(pubsubConfig) ||
      xor(is.null(github), is.null(triggerTemplate))
  )

  if (!is.null(github)) {
    assert_that(is.gar_GitHubEventsConfig(github))
  }

  if (!is.null(triggerTemplate)) {
    assert_that(is.gar_RepoSource(triggerTemplate))
  }

  structure(rmNullObs(list(
    filename = filename,
    name = name,
    tags = tags,
    build = build,
    ignoredFiles = ignoredFiles,
    github = github,
    substitutions = substitutions,
    sourceToBuild = sourceToBuild,
    includedFiles = includedFiles,
    disabled = disabled,
    triggerTemplate = triggerTemplate,
    pubsubConfig = pubsubConfig,
    webhookConfig = webhookConfig,
    description = description
  )),
  class = c("BuildTrigger", "list")
  )
}

is.gar_BuildTrigger <- function(x) {
  inherits(x, "BuildTrigger")
}

as.BuildTrigger <- function(x) {
  assert_that(is.buildTriggerResponse(x))

  BuildTrigger(
    filename = x$filename,
    name = x$name,
    tags = x$tags,
    build = x$build,
    ignoredFiles = x$ignoredFiles,
    github = x$github,
    substitutions = x$substitutions,
    sourceToBuild = x$sourceToBuild,
    includedFiles = x$includedFiles,
    disabled = x$disabled,
    triggerTemplate = x$triggerTemplate,
    description = x$description
  )
}


#' Pubsub Config (Build Trigger)
#'
#' PubsubConfig describes the configuration of a trigger that creates a build whenever a Pub/Sub message is published.
#'
#' @param subscription Output only. Name of the subscription.
#' @param topic The name of the topic from which this subscription is receiving messages.
#' @param serviceAccountEmail Service account that will make the push request.
#' @param state Potential issues with the underlying Pub/Sub subscription configuration. Only populated on get requests.
#'
#' @return A PubsubConfig object
#' @seealso `https://cloud.google.com/build/docs/api/reference/rest/v1/projects.locations.triggers#BuildTrigger.PubsubConfig`
#'
#' @export
PubsubConfig <- function(subscription = NULL,
                         topic = NULL,
                         serviceAccountEmail = NULL,
                         state = NULL) {
  structure(rmNullObs(
    list(
      subscription = subscription,
      topic = topic,
      serviceAccountEmail = serviceAccountEmail,
      state = state
    )
  ),
  class = c("gar_pubsubConfig", "list")
  )
}

is.gar_pubsubConfig <- function(x) {
  inherits(x, "gar_pubsubConfig")
}

#' WebhookConfig (Build Triggers)
#'
#' WebhookConfig describes the configuration of a trigger that creates a build whenever a webhook is sent to a trigger's webhook URL.
#'
#' @param state Potential issues with the underlying Pub/Sub subscription configuration. Only populated on get requests.
#' @param secret Resource name for the secret required as a URL parameter.
#'
#' @return A WebhookConfig object
#'
#' @export
WebhookConfig <- function(secret, state = NULL) {
  structure(rmNullObs(
    list(
      secret = secret,
      state = state
    )
  ),
  class = c("gar_webhookConfig", "list")
  )
}

is.gar_webhookConfig <- function(x) {
  inherits(x, "gar_webhookConfig")
}

#' GitRepoSource
#' Used for PubSub triggers
GitRepoSource <- function(uri,
                          ref,
                          repoType = c("GITHUB","CLOUD_SOURCE_REPOSITORIES")){

  assert_that(
    is.string(uri),
    is.string(ref),
    isTRUE(grepl("^refs/"))
  )

  repoType <- match.arg(repoType)

  structure(
    list(
      uri = uri,
      ref = ref,
      repoType = repoType
    ),
    class = c("gar_gitRepoSource","list")
  )
}

is.gitRepoSource <- function(x){
  inherits(x, "gar_gitRepoSource")
}

as.gitRepoSource <- function(x){
  if(!is.buildtrigger_repo(x)){
    stop("is not buildtrigger repo")
  }

  if(is.gar_GitHubEventsConfig(x$repo)){
      return(
        GitRepoSource(
          uri = paste0(x$repo$owner, "/", x$repo$name),
          ref = paste0("refs/", x$repo$push$branch), # ???
          repoType = "GITHUB"
        )
      )
  }

  stop("Could not convert via as.gitRepoSource")

}

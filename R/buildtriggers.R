#' Returns information about a `BuildTrigger`.This API is experimental.
#'
#' @family BuildTrigger functions
#' @param projectId ID of the project that owns the trigger
#' @param triggerId ID of the `BuildTrigger` to get or a \code{BuildTriggerResponse} object
#' @importFrom googleAuthR gar_api_generator
#' @export
cr_buildtrigger_get <- function(triggerId,
                                projectId = cr_project_get()) {

    triggerId <- get_buildTriggerResponseId(triggerId)

    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s",
        projectId, triggerId)
    # cloudbuild.projects.triggers.get
    f <- gar_api_generator(url,
                           "GET",
                           data_parse_function = as.buildTriggerResponse)
    f()

}

#' Updates a `BuildTrigger` by its project ID and trigger ID.This API is experimental.
#'
#' Seems not to work at the moment (issue #16)
#'
#' @param BuildTrigger The \link{BuildTrigger} object to update to
#' @param projectId ID of the project that owns the trigger
#' @param triggerId ID of the `BuildTrigger` to edit or a previous \code{BuildTriggerResponse} object that will be edited
#' @importFrom googleAuthR gar_api_generator
#' @family BuildTrigger functions
#'
#' @examples
#'
#' \dontrun{
#'
#' github <- GitHubEventsConfig("MarkEdmondson1234/googleCloudRunner",
#'                             branch = "master")
#' bt2 <- cr_buildtrigger("trig2",
#'                        trigger = github,
#'                        build = "inst/cloudbuild/cloudbuild.yaml")
#' bt3 <- BuildTrigger(
#'   filename = "inst/cloudbuild/cloudbuild.yaml",
#'   name = "edited1",
#'   tags = "edit",
#'   github = github,
#'   disabled = TRUE,
#'   description = "edited trigger")
#'
#' edited <- cr_buildtrigger_edit(bt3, triggerId = bt2)
#'
#' }
#'
#' @export
cr_buildtrigger_edit <- function(BuildTrigger,
                                 triggerId,
                                 projectId = cr_project_get()) {

    triggerId <- get_buildTriggerResponseId(triggerId)
    BuildTrigger$id <- triggerId

    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s",
        projectId, triggerId)
    # cloudbuild.projects.triggers.patch
    f <- gar_api_generator(url, "PATCH",
                           data_parse_function = as.buildTriggerResponse,
                           checkTrailingSlash = TRUE)
    stopifnot(inherits(BuildTrigger, "BuildTrigger"))

    f(the_body = BuildTrigger)

}

#' Deletes a `BuildTrigger` by its project ID and trigger ID.This API is experimental.
#'
#' @family BuildTrigger functions
#' @param projectId ID of the project that owns the trigger
#' @param triggerId ID of the `BuildTrigger` to get or a \code{BuildTriggerResponse} object
#' @importFrom googleAuthR gar_api_generator
#' @export
cr_buildtrigger_delete <- function(triggerId, projectId = cr_project_get()) {

    triggerId <- get_buildTriggerResponseId(triggerId)

    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s",
        projectId, triggerId)
    # cloudbuild.projects.triggers.delete
    f <- gar_api_generator(url, "DELETE",
                           data_parse_function = function(x) TRUE)
    f()

}

#' Lists existing `BuildTrigger`s.This API is experimental.
#'
#' @family BuildTrigger functions
#' @param projectId ID of the project for which to list BuildTriggers
#' @importFrom googleAuthR gar_api_generator
#' @export
cr_buildtrigger_list <- function(projectId = cr_project_get()){

    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers",
                   projectId)
    # cloudbuild.projects.triggers.list
    pars <-  list(pageToken = "", pageSize = 500)
    f <- gar_api_generator(url, "GET",
                           pars_args = rmNullObs(pars),
                           data_parse_function = parse_buildtrigger_list)

    o <- gar_api_page(f,
                      page_f = function(x) x$nextPageToken,
                      page_method = "param",
                      page_arg = "pageToken")

    Reduce(rbind, o)
}

parse_buildtrigger_list <- function(x){
  o <- x$triggers
  o$build <- NULL # use cr_buildtrigger_get to get build info of a build
  o$substitutions <- NULL
  o$triggerTemplate <- NULL
  o$createTime <- timestamp_to_r(o$createTime)
  o
}

#' Creates a new `BuildTrigger`.This API is experimental.
#'
#' @inheritParams BuildTrigger
#' @param trigger The trigger source created via \link{cr_buildtrigger_repo}
#' @param build The build to trigger created via \link{cr_build_make}, or the file location of the cloudbuild.yaml within the trigger source
#' @param projectId ID of the project for which to configure automatic builds
#' @param trigger_tags Tags for the buildtrigger listing
#' @importFrom googleAuthR gar_api_generator
#' @family BuildTrigger functions
#'
#' @details
#'
#' Any source specified in the build will be overwritten to use the trigger as a source (GitHub or Cloud Source Repositories)
#'
#' @export
#' @examples
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
#'                            package = "googleCloudRunner")
#' bb <- cr_build_make(cloudbuild)
#'
#' # repo hosted on GitHub
#' gh_trigger <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner")
#'
#' # repo mirrored to Cloud Source Repositories
#' cs_trigger <- cr_buildtrigger_repo("github_markedmondson1234_googlecloudrunner",
#'                                    type = "cloud_source")
#'
#' \dontrun{
#' # build with in-line build code
#' cr_buildtrigger(bb, name = "bt-github-inline", trigger = gh_trigger)
#'
#' # build with in-line build code using Cloud Source Repository
#' cr_buildtrigger(bb, name = "bt-github-inline", trigger = cs_trigger)
#'
#' # build pointing to cloudbuild.yaml within the GitHub repo
#' cr_buildtrigger("inst/cloudbuild/cloudbuild.yaml",
#'                  name = "bt-github-file", trigger = gh_trigger)
#'
#' # build with repo mirror from file
#' cr_buildtrigger("inst/cloudbuild/cloudbuild.yaml",
#'                  name = "bt-cs-file", trigger = cs_trigger)
#' }
cr_buildtrigger <- function(build,
                            name,
                            trigger,
                            description = paste("cr_buildtrigger: ", Sys.time()),
                            disabled = FALSE,
                            substitutions = NULL,
                            ignoredFiles = NULL,
                            includedFiles = NULL,
                            trigger_tags = NULL,
                            projectId = cr_project_get()) {

  assert_that(
    is.string(name),
    is.buildtrigger_repo(trigger)
  )

  # build from a file in the repo
  if(is.string(build)){
    the_build <- NULL
    the_filename <- build
  } else {
    assert_that(is.gar_Build(build))
    the_filename <- NULL

    # remove builds source
    build$source <- NULL
    the_build <- cr_build_make(build, source = NULL)

  }

  trigger_cloudsource <- NULL
  trigger_github <- NULL
  # trigger params
  if(trigger$type == "github"){
    trigger_github <- trigger$repo
  } else if(trigger$type == "cloud_source"){
    trigger_cloudsource <- trigger$repo
  }

  buildTrigger <- BuildTrigger(
      name = name,
      github = trigger_github,
      triggerTemplate=trigger_cloudsource,
      build = the_build,
      filename = the_filename,
      description = description,
      tags = trigger_tags,
      disabled = disabled,
      substitutions = substitutions,
      ignoredFiles = ignoredFiles,
      includedFiles = includedFiles
    )

  url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers",
                   projectId)
  # cloudbuild.projects.triggers.create
  f <- gar_api_generator(url, "POST",
                           data_parse_function = as.buildTriggerResponse)
  stopifnot(inherits(buildTrigger, "BuildTrigger"))

  f(the_body = buildTrigger)

}

as.buildTriggerResponse <- function(x){
    structure(
        x,
        class = c("BuildTriggerResponse", "list")
    )
}

is.buildTriggerResponse <- function(x){
    inherits(x, "BuildTriggerResponse")
}

get_buildTriggerResponseId <- function(x){
  if(is.buildTriggerResponse(x)){
    return(x$id)
  } else {
    assert_that(is.string(x))
  }

  x
}

#' Runs a `BuildTrigger` at a particular source revision.
#'
#' @param RepoSource The \link{RepoSource} object to pass to this method
#' @param projectId ID of the project
#' @param triggerId ID of the `BuildTrigger` to get or a \code{BuildTriggerResponse} object
#' @importFrom googleAuthR gar_api_generator
#' @family BuildTrigger functions
#' @export
cr_buildtrigger_run <- function(triggerId,
                                RepoSource,
                                projectId = cr_project_get()){

    triggerId <- get_buildTriggerResponseId(triggerId)

    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s:run",
        projectId, triggerId)

    # cloudbuild.projects.triggers.run
    f <- gar_api_generator(url, "POST",
                           data_parse_function = as.buildTriggerResponse)
    stopifnot(inherits(RepoSource, "gar_RepoSource"))

    f(the_body = RepoSource)

}

#' Copy a buildtrigger
#'
#' This lets you use the response from \link{cr_buildtrigger_get} for an existing buildtrigger to copy over settings to a new buildtrigger.
#'
#' @param buildtrigger A \code{CloudBuildTriggerResponse} object from \link{cr_buildtrigger_get}
#' @param projectId The projectId you are copying to
#' @inheritParams BuildTrigger
#'
#' @details Overwrite settings for the build trigger you are copying by supplying it as one of the other arguments from \link{BuildTrigger}.
#'
#'
#' @export
#' @family BuildTrigger functions
#' @import assertthat
#' @examples
#'
#' \dontrun{
#' #copying a GitHub buildtrigger across projects and git repos
#' bt <- cr_buildtrigger_get("my-trigger", projectId = "my-project-1")
#'
#' # a new GitHub project
#' gh <- GitHubEventsConfig("username/new-repo",
#'                          event = "push",
#'                          branch = "^master$")
#'
#' # give 'Cloud Build Editor' role to your service auth key in new project
#' # then copy configuration across
#' cr_buildtrigger_copy(bt, github = gh, projectId = "my-new-project")
#'
#'
#' }
cr_buildtrigger_copy <- function(buildtrigger,
                                 filename = NULL,
                                 name = NULL,
                                 tags = NULL,
                                 build = NULL,
                                 ignoredFiles = NULL,
                                 github = NULL,
                                 substitutions = NULL,
                                 includedFiles = NULL,
                                 disabled = NULL,
                                 triggerTemplate = NULL,
                                 projectId = cr_project_get()){

  assert_that(is.buildTriggerResponse(buildTrigger))

  if(!is.null(name)) buildTrigger$name <- name
  if(!is.null(filename)){
    buildTrigger$filename <- filename
    buildTrigger$build <- NULL
  }
  if(!is.null(build)){
    buildTrigger$build <- build
    buildTrigger$filename <- NULL
  }
  if(!is.null(tags)) buildTrigger$tags <- tags
  if(!is.null(ignoredFiles)) buildTrigger$ignoredFiles <- ignoredFiles
  if(!is.null(includedFiles)) buildTrigger$includedFiles <- includedFiles
  if(!is.null(substitutions)) buildTrigger$substitutions <- substitutions
  if(!is.null(github)){
    buildTrigger$github <- github
    buildTrigger$triggerTemplate <- NULL
  }
  if(!is.null(triggerTemplate)){
    buildTrigger$github <- NULL
    buildTrigger$triggerTemplate <- triggerTemplate
  }
  if(!is.null(disabled)) buildTrigger$disabled <- disabled

  buildTrigger <- as.BuildTrigger(buildTrigger)
  url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers",
                 projectId)
  # cloudbuild.projects.triggers.create
  f <- gar_api_generator(url, "POST",
                         data_parse_function = as.buildTriggerResponse)
  stopifnot(inherits(buildTrigger, "BuildTrigger"))

  f(the_body = buildTrigger)

}

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
#' @param triggerTemplate a \link{RepoSource} object - mutually exclusive with \code{github}
#' @param description Human-readable description of this trigger
#'
#' @seealso \url{https://cloud.google.com/cloud-build/docs/api/reference/rest/v1/projects.triggers}
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
                         triggerTemplate = NULL,
                         description = NULL) {

    assert_that(
        xor(is.null(build), is.null(filename)),
        xor(is.null(github), is.null(triggerTemplate))
    )

    if(!is.null(github)){
        assert_that(is.gar_GitHubEventsConfig(github))
    }

    if(!is.null(triggerTemplate)){
        assert_that(is.gar_RepoSource(triggerTemplate))
    }

    structure(rmNullObs(list(filename = filename,
                   name = name,
                   tags = tags,
                   build = build,
                   ignoredFiles = ignoredFiles,
                   github = github,
                   substitutions = substitutions,
                   includedFiles = includedFiles,
                   disabled = disabled,
                   triggerTemplate = triggerTemplate,
                   description = description)),
            class = c("BuildTrigger","list"))
}

is.gar_BuildTrigger <- function(x){
    inherits(x, "BuildTrigger")
}

as.BuildTrigger <- function(x){
  assert_that(is.buildTriggerResponse(x))

  BuildTrigger(filename = x$filename,
               name = x$name,
               tags = x$tags,
               build = x$build,
               ignoredFiles = x$ignoredFiles,
               github = x$github,
               substitutions = x$substitutions,
               includedFiles = x$includedFiles,
               disabled = x$disabled,
               triggerTemplate = x$triggerTemplate,
               description = x$description)

}

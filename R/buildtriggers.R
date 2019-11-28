#' Returns information about a `BuildTrigger`.This API is experimental.
#'
#' @family BuildTrigger functions
#' @param projectId ID of the project that owns the trigger
#' @param triggerId ID of the `BuildTrigger` to get
#' @importFrom googleAuthR gar_api_generator
#' @export
cr_buildtrigger_get <- function(projectId, triggerId) {
    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s",
        projectId, triggerId)
    # cloudbuild.projects.triggers.get
    f <- gar_api_generator(url,
                           "GET",
                           data_parse_function = function(x) x)
    f()

}

#' Updates a `BuildTrigger` by its project ID and trigger ID.This API is experimental.
#'
#'
#' @param BuildTrigger The \link{BuildTrigger} object to pass to this method
#' @param projectId ID of the project that owns the trigger
#' @param triggerId ID of the `BuildTrigger` to update
#' @importFrom googleAuthR gar_api_generator
#' @family BuildTrigger functions
#' @export
cr_buildtrigger_edit <- function(BuildTrigger, projectId, triggerId) {
    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s",
        projectId, triggerId)
    # cloudbuild.projects.triggers.patch
    f <- gar_api_generator(url, "PATCH",
                           data_parse_function = function(x) x)
    stopifnot(inherits(BuildTrigger, "gar_BuildTrigger"))

    f(the_body = BuildTrigger)

}

#' Deletes a `BuildTrigger` by its project ID and trigger ID.This API is experimental.
#'
#' @family BuildTrigger functions
#' @param projectId ID of the project that owns the trigger
#' @param triggerId ID of the `BuildTrigger` to delete
#' @importFrom googleAuthR gar_api_generator
#' @export
cr_buildtrigger_delete <- function(projectId, triggerId) {

    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s",
        projectId, triggerId)
    # cloudbuild.projects.triggers.delete
    f <- gar_api_generator(url, "DELETE",
                           data_parse_function = function(x) x)
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
    pars = list(pageToken = "", pageSize = 500)
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
#' @param trigger The trigger which will be a \link{RepoSource} or a \link{GitHubEventsConfig}
#' @param build A file location within the trigger source to use for the build steps, or a \link{Build} object
#' @param projectId ID of the project for which to configure automatic builds
#' @importFrom googleAuthR gar_api_generator
#' @family BuildTrigger functions
#' @export
cr_buildtrigger <- function(name,
                            trigger,
                            build,
                            description = NULL,
                            tags = NULL,
                            disabled = FALSE,
                            substitutions = NULL,
                            ignoredFiles = NULL,
                            includedFiles = NULL,
                            projectId = cr_project_get()) {

    buildTrigger <- buildtrigger_make(
        name = name,
        trigger = trigger,
        build = build,
        description = description,
        tags = tags,
        disabled = disabled,
        substitutions = substitutions,
        ignoredFiles = ignoredFiles,
        includedFiles = includedFiles
    )

    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers",
                   projectId)
    # cloudbuild.projects.triggers.create
    f <- gar_api_generator(url, "POST",
                           data_parse_function = function(x) x)
    stopifnot(inherits(buildTrigger, "gar_BuildTrigger"))

    f(the_body = buildTrigger)

}

#' Runs a `BuildTrigger` at a particular source revision.
#'
#' @param RepoSource The \link{RepoSource} object to pass to this method
#' @param projectId ID of the project
#' @param triggerId ID of the trigger
#' @importFrom googleAuthR gar_api_generator
#' @family BuildTrigger functions
#' @export
cr_buildtrigger_run <- function(RepoSource, projectId, triggerId){

    url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s:run",
        projectId, triggerId)

    # cloudbuild.projects.triggers.run
    f <- gar_api_generator(url, "POST",
                           data_parse_function = function(x) x)
    stopifnot(inherits(RepoSource, "gar_RepoSource"))

    f(the_body = RepoSource)

}

#' Create a BuildTrigger Object
#'
#' Use this to make the object to pass to \link{cr_buildtrigger}
#'
#' @export
#' @noRd
buildtrigger_make <- function(name,
                              trigger,
                              build,
                              description = NULL,
                              tags = NULL,
                              disabled = FALSE,
                              substitutions = NULL,
                              ignoredFiles = NULL,
                              includedFiles = NULL){

    assert_that(any(is.gar_Build(build), is.string(build)),
                is.string(name))

    UseMethod("buildtrigger_make", trigger)
}

#' @noRd
#' @export
buildtrigger_make.RepoSource <- function(name,
                                            trigger,
                                            build,
                                            description = NULL,
                                            tags = NULL,
                                            disabled = FALSE,
                                            substitutions = NULL,
                                            ignoredFiles = NULL,
                                            includedFiles = NULL){

    if(is.string(build)){
        filename <- build
        build <- NULL
    }

    BuildTrigger(
        name = name,
        triggerTemplate=trigger,
        build = build,
        filename = filename,
        description = description,
        tags = tags,
        disabled = disabled,
        substitutions = substitutions,
        ignoredFiles = ignoredFiles,
        includedFiles = includedFiles
    )

}

#' @noRd
#' @export
buildtrigger_make.GitHubEventsConfig <- function(name,
                                            trigger,
                                            build,
                                            description = NULL,
                                            tags = NULL,
                                            disabled = FALSE,
                                            substitutions = NULL,
                                            ignoredFiles = NULL,
                                            includedFiles = NULL){

    if(is.string(build)){
        filename <- build
        build <- NULL
    }

    BuildTrigger(
        name = name,
        github=trigger,
        build = build,
        filename = filename,
        description = description,
        tags = tags,
        disabled = disabled,
        substitutions = substitutions,
        ignoredFiles = ignoredFiles,
        includedFiles = includedFiles
    )

}

#' BuildTrigger Object
#'
#' Configuration for an automated build in response to source repositorychanges.
#'
#' @param substitutions A named list of Build macro variables
#' @param filename Path, from the source root, to a file whose contents is used for the
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

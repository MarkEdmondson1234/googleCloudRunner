#' Starts a build with the specified configuration.
#'
#' This method returns a long-running `Operation`, which includes the buildID. Pass the build ID to \link{cr_build_status} to determine the build status (such as `SUCCESS` or `FAILURE`).
#'
#'
#' @seealso \href{https://cloud.google.com/cloud-build/docs/}{Google Documentation for Cloud Build}
#'
#' @inheritParams Build
#' @param projectId ID of the project
#' @param x A cloudbuild.yaml file location or an R object that will be turned into yaml via \link[yaml]{as.yaml} or a \link{Build} object created by \link{cr_build_make} or from a previous build you want to rerun.
#' @param launch_browser Whether to launch the logs URL in a browser once deployed
#' @importFrom googleAuthR gar_api_generator
#' @importFrom yaml yaml.load_file
#' @import assertthat
#' @family Cloud Build functions
#' @export
#' @examples
#' cr_project_set("my-project")
#' my_gcs_source <- cr_build_source(StorageSource("my_code.tar.gz",
#'                                              bucket = "gs://my-bucket"))
#' my_gcs_source
#'
#' my_repo_source <- cr_build_source(RepoSource("github_username_my-repo.com",
#'                                            branchName="master"))
#' my_repo_source
#' \dontrun{
#'
#' # build from a cloudbuild.yaml file
#' cloudbuild_file <- system.file("cloudbuild/cloudbuild.yaml",
#'                                package="googleCloudRunner")
#'
#' # asynchronous, will launch log browser by default
#' b1 <- cr_build(cloudbuild_file)
#'
#' # synchronous waiting for build to finish
#' b2 <- cr_build_wait(b1)
#'
#' # the same results
#' cr_build_status(b1)
#' cr_build_status(b2)
#'
#' # build from a cloud storage source
#' build1 <- cr_build(cloudbuild_file,
#'                    source = my_gcs_source)
#' # build from a git repository source
#' build2 <- cr_build(cloudbuild_file,
#'                    source = my_repo_source)
#'
#' # you can send in results for previous builds to trigger
#' # the same build under a new Id
#' # will trigger build2 again
#' cr_build(build2)
#'
#' # a build with substitutions (Cloud Build macros)
#' cr_build(build2, substitutions = list(`_SUB` = "yo"))
#'
#' }
cr_build <- function(x,
                     source = NULL,
                     timeout=NULL,
                     images=NULL,
                     substitutions=NULL,
                     artifacts = NULL,
                     options = NULL,
                     projectId = cr_project_get(),
                     launch_browser = interactive()) {

  assert_that(
    is.flag(launch_browser),
    is.string(projectId)
  )

  timeout <- check_timeout(timeout)

  url <- sprintf("https://cloudbuild.googleapis.com/v1/projects/%s/builds",
                 projectId)

  if(is.gar_Build(x)){
    # turn existing build into a valid new build
    build <- safe_set(x, "status", "QUEUED")

  } else if(is.BuildOperationMetadata(x)){
    x <- as.gar_Build(x)
    build <- safe_set(x, "status", "QUEUED")
  } else {
    build <- cr_build_make(yaml = x,
                           source = source,
                           timeout = timeout,
                           images = images,
                           artifacts = artifacts,
                           options = options,
                           substitutions = substitutions)
  }


  parse_f <- function(x){
    structure(x,class = "BuildOperationMetadata")
  }
  # cloudbuild.projects.builds.create
  f <- gar_api_generator(url, "POST",
         data_parse_function = parse_f)
  stopifnot(is.gar_Build(build))

  o <- f(the_body = build)

  logs <- extract_logs(o)
  cli::cli_alert_info("Cloud Build started - logs:")
  cli::cli_text("{.url {logs}}")

  if(launch_browser){
    utils::browseURL(logs)
  }

  invisible(o)
}

is.BuildOperationMetadata <- function(x){
  inherits(x, "BuildOperationMetadata")
}



extract_logs <- function(o){
  if(is.BuildOperationMetadata(o)){
    return(o$metadata$build$logUrl)
  } else if(is.gar_Build(o)){
    return(o$logUrl)
  } else {
    warning("Could not extract logUrl from class: ", class(o))
  }
}

#' Make a Cloud Build object out of a cloudbuild.yml file
#'
#' This creates a \link{Build} object via the standard cloudbuild.yaml format
#'
#' @seealso https://cloud.google.com/cloud-build/docs/build-config
#'
#' @inheritParams cr_build
#' @param yaml A \code{Yaml} object created from \link{cr_build_yaml} or a file location of a .yaml/.yml cloud build file
#' @param artifacts Artifacts that may be built via \link{cr_build_yaml_artifact}
#' @param options Options to pass to a Cloud Build
#' @param availableSecrets Secret Manager objects built by \link{cr_build_yaml_secrets}
#' @param logsBucket The gs:// location of a bucket to put logs in
#'
#' @export
#' @import assertthat
#' @family Cloud Build functions
#' @examples
#' cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
#'                            package = "googleCloudRunner")
#' cr_build_make(cloudbuild)
cr_build_make <- function(yaml,
                          source = NULL,
                          timeout=NULL,
                          images=NULL,
                          artifacts = NULL,
                          options = NULL,
                          substitutions = NULL,
                          availableSecrets = NULL,
                          logsBucket = NULL){

  stepsy <- get_cr_yaml(yaml)
  if(is.null(stepsy$steps)){
    stop("Invalid cloudbuild yaml - 'steps:' not found.", call. = FALSE)
  }

  timeout <- check_timeout(timeout)
  if(is.null(timeout) && !is.null(stepsy$timeout)){
    timeout <- stepsy$timeout
  }

  if(!is.null(source)){
    assert_that(is.gar_Source(source))
  }

  if(is.null(images) && !is.null(stepsy$images)){
    images <- stepsy$images
  }

  if(is.null(artifacts) && !is.null(stepsy$artifacts)){
    artifacts <- stepsy$artifacts
  }

  if(is.null(options) && !is.null(stepsy$options)){
    options <- stepsy$options
  }

  if(is.null(substitutions) && !is.null(stepsy$substitutions)){
    substitutions <- stepsy$substitutions
  }

  if(is.null(logsBucket) && !is.null(stepsy$logsBucket)){
    logsBucket <- stepsy$logsBucket
  }

  if(is.null(availableSecrets) && !is.null(stepsy$availableSecrets)){
    as <- stepsy$availableSecrets
  } else {
    as <- parse_yaml_secret_list(availableSecrets)
  }

  Build(steps = stepsy$steps,
        timeout = timeout,
        images = images,
        source = source,
        options = options,
        substitutions = substitutions,
        artifacts = artifacts,
        availableSecrets = as,
        logsBucket = logsBucket)
}



#' Create a cloudbuild Yaml object in R
#'
#' This can be written to disk or used directly with functions such as \link{cr_build}
#'
#' @param steps A vector of \link{cr_buildstep}
#' @param timeout How long the entrie build will run. If not set will be 10mins
#' @param logsBucket Where logs are written.  If you don't set this field, Cloud Build will use a default bucket to store your build logs.
#' @param options A named list of options
#' @param substitutions Build macros that will replace entries in other elements
#' @param tags Tags for the build
#' @param secrets A secrets object
#' @param images What images will be build from this cloudbuild
#' @param artifacts What artifacts may be built from this cloudbuild
#'
#' @seealso \href{Build configuration overview for cloudbuild.yaml}{https://cloud.google.com/cloud-build/docs/build-config}
#' @export
#' @family Cloud Build functions
#' @examples
#' image <- "gcr.io/my-project/my-image"
#' cr_build_yaml(steps = c(
#'     cr_buildstep("docker", c("build","-t",image,".")),
#'     cr_buildstep("docker", c("push",image)),
#'     cr_buildstep("gcloud", c("beta","run","deploy", "test1", "--image", image))),
#'   images = image)
cr_build_yaml <- function(steps,
                          timeout = NULL,
                          logsBucket = NULL,
                          options = NULL,
                          substitutions = NULL,
                          tags = NULL,
                          secrets = NULL,
                          images = NULL,
                          artifacts = NULL){

  timeout <- check_timeout(timeout)

  Yaml(
    steps = steps,
    timeout = timeout,
    logsBucket = logsBucket,
    options = options,
    substitutions = substitutions,
    tags = tags,
    secrets = secrets,
    images = images,
    artifacts = artifacts
  )
}

#' Add an artifact for cloudbuild.yaml
#'
#' Add artifact objects to a build
#'
#' @param paths Which files from the working directory to upload to cloud storage once the build is finished.  Can use globs but see details of \link{cr_build_artifacts} on how that affects downloads
#' @param bucket_dir The directory in the bucket the files will be uploaded to
#' @param bucket the bucket to send to
#' @family Cloud Build functions
#' @export
#' @examples
#'
#' r <- "write.csv(mtcars,file = 'artifact.csv')"
#' cr_build_yaml(
#'   steps = cr_buildstep_r(r),
#'   artifacts = cr_build_yaml_artifact('artifact.csv')
#'   )
cr_build_yaml_artifact <- function(paths,
                                   bucket_dir = NULL,
                                   bucket = cr_bucket_get()){
  if(grepl("^gs://", bucket)){
    location <- bucket
  } else {
    location <- paste0("gs://", bucket)
  }


  if(!is.null(bucket_dir)){
    location <- paste0(location, "/", bucket_dir)
  }

  list(
    objects = list(
      location = location,
      paths = paths
    )
  )
}



#' @noRd
#' @import assertthat
check_timeout <- function(timeout){

  if(is.null(timeout)) return(NULL)

  if(is.string(timeout)){
    assert_that(grepl("s$", timeout))
    return(timeout)
  }

  assert_that(is.numeric(timeout))
  paste0(as.integer(timeout),"s")

}



#' Helper to create yaml files
#'
#' @param ... steps in the yaml object
#'
#' @noRd
#' @family Cloud Build functions, yaml functions
#' @examples
#'
#'Yaml(steps = c(
#'       cr_buildstep("docker", "version"),
#'       cr_buildstep("gcloud", "version")),
#'     images = "gcr.io/my-project/my-image",
#'     timeout = "660s")
Yaml <- function(...){
  structure(
    rmNullObs(list(...)),
    class = c("cr_yaml","list")
  )
}

is.Yaml <- function(x){
  inherits(x, "cr_yaml")
}

#' @import assertthat
#' @importFrom yaml read_yaml
#' @noRd
get_cr_yaml <- function(x){
  if(is.Yaml(x)){
    return(x)
  } else if(assertthat::is.string(x)){
    # its a yaml file
    assert_that(
      is.readable(x),
      grepl("\\.ya?ml$", x, ignore.case = TRUE)
    )
  } else {
    stop("Yaml is not class(yaml) or a filepath - class:", class(x))
  }

  read_yaml(x)
}

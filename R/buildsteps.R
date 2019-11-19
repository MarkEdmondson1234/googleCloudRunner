#' Create a yaml build step
#'
#' Helper for creating build steps for upload to Cloud Build
#'
#' @param name name of SDK appended to stem
#' @param args character vector of arguments
#' @param prefix prefixed to name - set to "" to suppress
#' @param entrypoint change the entrypoint for the docker container
#' @param dir The directory to use, relative to /workspace e.g. /workspace/deploy/
#' @param id Optional id for the step
#'
#' @details
#' By default dir is set to \code{deploy} to aid deployment from GCS, but you may want to set this to \code{""} when using \link{RepoSource}
#'
#' @export
#' @family Cloud Build functions, yaml functions
#' @examples
#'
#' # creating yaml for use in deploying cloud run
#' image = "gcr.io/my-project/my-image:$BUILD_ID"
#' Yaml(
#'     steps = c(
#'          cr_buildstep("docker", c("build","-t",image,".")),
#'          cr_buildstep("docker", c("push",image)),
#'          cr_buildstep("gcloud", c("beta","run","deploy", "test1",
#'                                    "--image", image))),
#'     images = image)
#'
#' # use premade docker buildstep - combine using c()
#' image = "gcr.io/my-project/my-image"
#' Yaml(
#'     steps = c(cr_buildstep_docker(image),
#'               cr_buildstep("gcloud",
#'                      args = c("beta","run","deploy",
#'                               "test1","--image", image))
#'              ),
#'     images = image)
#'
#' # list files with a new entrypoint for gcloud
#' Yaml(steps = cr_buildstep("gcloud", c("-c","ls -la"), entrypoint = "bash"))
#'
#' # to call from images not using gcr.io/cloud-builders stem
#' cr_buildstep("alpine", c("-c","ls -la"), entrypoint = "bash", stem="")
#'
cr_buildstep <- function(name,
                         args,
                         id = NULL,
                         prefix = "gcr.io/cloud-builders/",
                         entrypoint = NULL,
                         dir = "deploy"){

  prefix <- if(is.null(prefix) || is.na(prefix)) "gcr.io/cloud-builders/" else prefix

  list(structure(
    rmNullObs(list(
      name = paste0(prefix, name),
      entrypoint = entrypoint,
      args = args,
      id = id,
      dir = dir
    )), class = c("cr_buildstep","list")))
}

is.cr_buildstep <- function(x){
  inherits(x, "cr_buildstep")
}

#' Convert a data.frame into cr_buildstep
#'
#' Helper to turn a data.frame of buildsteps info into format accepted by \link{cr_build}
#'
#' @param x A data.frame of steps to turn into buildsteps, with at least name and args columns
#'
#' @details
#' This helps convert the output of \link{cr_build} into valid \link{cr_buildstep} so it can be sent back into the API
#'
#' If constructing arg list columns then \link{I} suppresses conversion of the list to columns that would otherwise break the yaml format
#' @export
#' @examples
#'
#' \dontrun{
#'
#' y <- data.frame(name = c("docker", "alpine"),
#'                 args = I(list(c("version"), c("echo", "Hello Cloud Build"))),
#'                 id = c("Docker Version", "Hello Cloud Build"),
#'                 prefix = c(NA, "")
#'                 stringsAsFactors = FALSE)
#' cr_buildstep_df(y)
#'
#' }
cr_buildstep_df <- function(x){
  assert_that(
    is.data.frame(x),
    all(c('name', 'args') %in% names(x))
  )

  apply(x, 1, function(row){
    cr_buildstep(name = row[["name"]],
                 args = row[["args"]],
                 id = row[["id"]],
                 prefix = row[["prefix"]],
                 entrypoint = row[["entrypoint"]],
                 dir = row[["dir"]])[[1]]
  })

}

#' Create a build step for decrypting files via KMS
#'
#' Create a build step to decrypt files using CryptoKey from Cloud Key Management Service
#'
#' @param cipher The file that has been encrypted
#' @param plain The file location to decrypt to
#' @param keyring The KMS keyring to use
#' @param key The KMS key to use
#' @param location The KMS location
#' @param dir The directory relative to /workspace/ the command will operate in
#'
#' @details
#' You will need to set up the encrypted key using gcloud following this guide from Google: https://cloud.google.com/cloud-build/docs/securing-builds/use-encrypted-secrets-credentials
#'
#'
#' @export
#' @examples
#'
#' cr_buildstep_decrypt("secret.json.enc",
#'                      plain = "secret.json",
#'                      keyring = "my_keyring",
#'                      key = "my_key")
cr_buildstep_decrypt <- function(cipher,
                                 plain,
                                 keyring,
                                 key,
                                 location="global",
                                 dir=""){
    cr_buildstep("gcloud",
                 args = c("kms", "decrypt",
                          "--ciphertext-file", cipher,
                          "--plaintext-file", plain,
                          "--location", location,
                          "--keyring", keyring,
                          "--key", key),
                 dir = dir)
}

#' Create a build step to build and push a docker image
#'
#' @param image The image tag that will be pushed, starting with gcr.io or created by combining with \code{projectId} if not starting with gcr.io
#' @param tag The tag to attached to the pushed image - can use \code{Build} macros
#' @param location Where the Dockerfile to build is in relation to \code{dir}
#' @param dir The workspace folder on cloud build, eg /workspace/deploy/.  Default is equivalent to /workspace/
#' @param projectId The projectId
#'
#' @export
#' @import assertthat
#' @examples
#' cr_buildstep_docker("gcr.io/my-project/my-image")
#' cr_buildstep_docker("my-image")
#' cr_buildstep_docker("my-image", tag = "$BRANCH_NAME")
cr_buildstep_docker <- function(image,
                                tag = "$BUILD_ID",
                                location = ".",
                                dir="",
                                projectId = cr_project_get()){
  prefix <- grepl("^gcr.io", image)
  if(prefix){
    the_image <- image
  } else {
    the_image <- paste0("gcr.io/", projectId, "/", image)
  }

  the_image <- paste0(the_image, ":", tag)
  myMessage("Image to be built: ", the_image, level = 3)

  c(
    cr_buildstep("docker", c("build","-t",the_image,location), dir=dir),
    cr_buildstep("docker", c("push", the_image), dir=dir)
  )
}

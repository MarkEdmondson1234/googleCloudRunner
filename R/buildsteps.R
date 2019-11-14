#' Create a yaml build step
#'
#' Helper for creating build steps for upload to Cloud Build
#'
#' @param name name of SDK appended to stem
#' @param args character vector of arguments
#' @param stem prefixed to name
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
#' image = "gcr.io/my-project/my-image$BUILD_ID"
#' Yaml(
#'     steps = list(
#'          cr_buildstep("docker", c("build","-t",image,".")),
#'          cr_buildstep("docker", c("push",image)),
#'          cr_buildstep("gcloud", c("beta","run","deploy", "test1",
#'                                    "--image", image))),
#'     images = image)
#'
#' # list files with a new entrypoint for gcloud
#' Yaml(steps = cr_buildstep("gcloud", c("-c","ls -la"), entrypoint = "bash"))
#'
cr_buildstep <- function(name,
                         args,
                         id = NULL,
                         stem = "gcr.io/cloud-builders/",
                         entrypoint = NULL,
                         dir = "deploy"){
  rmNullObs(list(
    name = paste0(stem, name),
    entrypoint = entrypoint,
    args = args,
    id = id,
    dir = dir
  ))
}

#' Create a build step for decrypting files via KMS
#'
#' @param cipher The file that has been encrypted
#' @param plain The file location to decrypt to
#' @param keyring The KMS keyring to use
#' @param key The KMS key to use
#' @param location The KMS location
#'
#' @export
cr_buildstep_decrypt <- function(cipher,
                                 plain,
                                 keyring,
                                 key,
                                 locataion="global"){
  list(
    cr_buildstep("gcloud",
                 args = c("kms", "decrypt",
                          "--ciphertext-file", "secrets.json.enc",
                          "--plaintext-file", "auth.json",
                          "--location", "global",
                          "--keyring", "cloudbuild",
                          "--key", "bq"),
                 dir = "")
  )
}
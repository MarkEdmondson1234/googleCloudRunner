#' Create a build step for decrypting files via KMS
#'
#' Create a build step to decrypt files using CryptoKey from Cloud Key Management Service
#'
#' @param cipher The file that has been encrypted
#' @param plain The file location to decrypt to
#' @param keyring The KMS keyring to use
#' @param key The KMS key to use
#' @param location The KMS location
#' @param ... Further arguments passed in to \link{cr_buildstep}
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
                                 ...){
  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$name),
    is.null(dots$args),
    is.null(dots$prefix),
    is.null(dots$entrypoint)
  )
  cr_buildstep("gcloud",
               args = c("kms", "decrypt",
                        "--ciphertext-file", cipher,
                        "--plaintext-file", plain,
                        "--location", location,
                        "--keyring", keyring,
                        "--key", key),
               ...)
}

#' Create a build step to build and push a docker image
#'
#' @param image The image tag that will be pushed, starting with gcr.io or created by combining with \code{projectId} if not starting with gcr.io
#' @param tag The tag to attached to the pushed image - can use \code{Build} macros
#' @param location Where the Dockerfile to build is in relation to \code{dir}
#' @param ... Further arguments passed in to \link{cr_buildstep}
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
                                projectId = cr_project_get(),
                                ...){
  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$name),
    is.null(dots$args),
    is.null(dots$prefix),
    is.null(dots$entrypoint)
  )

  prefix <- grepl("^gcr.io", image)
  if(prefix){
    the_image <- image
  } else {
    the_image <- paste0("gcr.io/", projectId, "/", image)
  }

  the_image <- paste0(the_image, ":", tag)
  myMessage("Image to be built: ", the_image, level = 3)

  c(
    cr_buildstep("docker", c("build","-t",the_image,location), ...),
    cr_buildstep("docker", c("push", the_image), ...)
  )
}

#' Create a build step for authenticating with Git
#'
#' This creates steps to configure git to use an ssh created key.
#'
#' @inheritParams cr_buildstep_decrypt
#' @details
#'
#' The key should be encrypted offline using \code{gcloud kms} or similar first.  See \link{cr_buildstep_decrypt} for details.
#'
#' By default the encrypted key should then be at the root of your \link{Source} object called "id_rsa.enc"
#'
#' You also need to supply a \code{known_hosts} file in working directory.  This can be created by \code{ssh-keyscan -t rsa github.com > known_hosts}
#'
#' @rdname cr_buildstep_git
#' @export
#' @examples
#'
#' # assumes you have previously saved git ssh key via KMS called "git_key"
#' Yaml(
#'      steps = c(
#'           cr_buildstep_gitsetup("my_keyring", "git_key"),
#'           cr_buildstep_git(c("clone", "git@github.com:github_name/repo_name"))
#'      )
#'  )
#'
cr_buildstep_gitsetup <- function(keyring, key, cipher = "id_rsa.enc", ...){
  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$name),
    is.null(dots$args),
    is.null(dots$prefix),
    is.null(dots$entrypoint)
  )

  cb <- system.file("cloudbuild/cloudbuild_git.yml",
                    package = "googleCloudRunner")
  bs <- cr_build_make(cb)

  c(
    cr_buildstep_decrypt(cipher = cipher,
                         plain = "/root/.ssh/id_rsa",
                         keyring = keyring,
                         key = key,
                         volumes = git_volume()),
    cr_buildstep_extract(bs, 2)
  )
}


#' Create a build step for using Git
#'
#' This creates steps to use git with an ssh created key.
#'
#' @param ... Further arguments passed in to \link{cr_buildstep}
#' @param git_args The arguments to send to git
#' @details
#'
#' \code{cr_buildstep} must come after \code{cr_buildstep_gitsetup}
#'
#' @export
#' @examples
#'
cr_buildstep_git <- function(git_args = c("clone",
                                          "git@github.com:[GIT-USERNAME]/[REPOSITORY]"),
                             ...){
  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$name),
    is.null(dots$args),
    is.null(dots$prefix),
    is.null(dots$entrypoint)
  )

  cr_buildstep(
    "git",
    args = git_args,
    volumes = git_volume()
  )
}

git_volume <- function(){
  list(list(name = "ssh",
            path = "/root/.ssh"))
}

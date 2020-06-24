#' Create a build step for authenticating with Git
#'
#' This creates steps to configure git to use an ssh created key.
#'
#' @param secret The name of the secret on Google Secret Manager for the git ssh private key
#' @param post_setup Steps that occur after git setup
#' @details
#'
#' The ssh private key should be uploaded to Google Secret Manager first
#'
#' @seealso \href{https://cloud.google.com/cloud-build/docs/access-private-github-repos}{Accessing private GitHub repositories using Cloud Build (google article)}
#'
#' @rdname cr_buildstep_git
#' @export
#' @examples
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#'
#' # assumes you have previously saved git ssh key called "github-ssh"
#' cr_build_yaml(
#'      steps = c(
#'           cr_buildstep_gitsetup("github-ssh"),
#'           cr_buildstep_git(c("clone",
#'                              "git@github.com:github_name/repo_name"))
#'      )
#'  )
#'
cr_buildstep_gitsetup <- function(secret, post_setup = NULL){

  github_setup <- system.file("ssh", "github_setup.sh",
                              package = "googleCloudRunner")
  c(
    cr_buildstep_secret(secret = secret,
                        decrypted = "/root/.ssh/id_rsa",
                        volumes = git_volume(),
                        id = "git secret"),
    cr_buildstep_bash(github_setup,
                      name = "gcr.io/cloud-builders/git",
                      entrypoint = "bash",
                      volumes = git_volume(),
                      id = "git setup script"),
    post_setup
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
#' @family Cloud Buildsteps
#' @export
#' @import assertthat
cr_buildstep_git <- function(
  git_args = c("clone",
               "git@github.com:[GIT-USERNAME]/[REPOSITORY]",
               "."),
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
    volumes = git_volume(),
    ...
  )
}

#' @export
#' @rdname cr_buildstep_git
#' @details
#'
#' Use \code{git_volume} to add the git credentials folder to other buildsteps
#'
#' @examples
#'
#'
git_volume <- function(){
  list(list(name = "ssh",
            path = "/root/.ssh"))
}

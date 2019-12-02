#' Run an R script in a Cloud Build R step
#'
#' Helper to run R code within build steps, from either an existing local R file or within the source of the build.
#'
#' @param r R code to run or a file containing R code - see details
#' @param name The docker image that will run the R code, usually from rocker-project.org
#' @param r_source Whether the R code will be from a runtime file within the source or at build time copying over from a local R file in your session
#' @param ... Other arguments passed to \link{cr_buildstep}
#' @inheritParams cr_buildstep
#' @family Cloud Buildsteps
#'
#' @details
#'
#' If \code{r_source="runtime"} then \code{r} should be the location of that file within the source or \code{image} that will be run by the R code from \code{image}
#'
#' If \code{r_source="local"} then it will copy over from a character string or local file into the build step directly.
#'
#' @examples
#'
#' # create an R buildstep inline
#' cr_buildstep_r(c("paste('1+1=', 1+1)", "sessionInfo()"))
#'
#' \dontrun{
#'
#' # create an R buildstep from a local file
#' cr_buildstep_r("my-r-file.R")
#'
#' # create an R buildstep from a file within the source of the Build
#' cr_buildstep_r("inst/schedule/schedule.R", r_source = "runtime")
#'
#' }
#'
#' # use a different Rocker image e.g. rocker/verse
#' cr_buildstep_r(c("library(dplyr)",
#'                  "mtcars %>% select(mpg)",
#'                  "sessionInfo"),
#'                name = "verse")
#'
#' # use your own R image with custom R
#' my_r <- c("devtools::install()", "pkgdown::build_site()")
#' br <-  cr_buildstep_r(my_r, name= "gcr.io/gcer-public/packagetools:master")
#'
#'
#'
#' @export
cr_buildstep_r <- function(r,
                           name = "r-base",
                           r_source = c("local", "runtime"),
                           prefix = "rocker/",
                           ...){

  r_source <- match.arg(r_source)
  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$args),
    is.null(dots$name),
    is.null(dots$prefix)
  )

  rchars <- r
  if(r_source == "local"){
    assert_that(is.character(r))

    rchars <- r
    if(grepl("\\.R", r[[1]], ignore.case = TRUE)){
      # filepath
      assert_that(is.readable(r), is.string(r))
      rchars <- readLines(r)
      myMessage("Copying into build step R code from ", r, level = 3)
    }

    rchars <- paste(rchars, collapse = "\n")

  } else if(r_source == "runtime"){
    #filepath in source, not much we can do to check it
    myMessage("Will read R code in source from filepath ", rchars, level = 3)
  }

  cr_buildstep(name = name,
               args = c("Rscript", "-e", rchars),
               prefix = prefix,
               ...)

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
#' @param ... Further arguments passed in to \link{cr_buildstep}
#' @details
#' You will need to set up the encrypted key using gcloud following this guide from Google: https://cloud.google.com/cloud-build/docs/securing-builds/use-encrypted-secrets-credentials
#'
#' @family Cloud Buildsteps
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
#' @family Cloud Buildsteps
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
#' @param keyring The Key Management Store keyring containing the git ssh key
#' @param key The Key Management Store key containing the gitssh key
#' @param cipher The filename of the encrypted git ssh key that has been checked into the repository
#' @details
#'
#' The key should be encrypted offline using \code{gcloud kms} or similar first.  See \link{cr_buildstep_decrypt} for details.
#'
#' By default the encrypted key should then be at the root of your \link{Source} object called "id_rsa.enc"
#'
#' @seealso \href{https://cloud.google.com/cloud-build/docs/access-private-github-repos}{Accessing private GitHub repositories using Cloud Build (google article)}
#'
#' @rdname cr_buildstep_git
#' @export
#' @examples
#'
#' # assumes you have previously saved git ssh key via KMS called "git_key"
#' Yaml(
#'      steps = c(
#'           cr_buildstep_gitsetup("my_keyring", "git_key"),
#'           cr_buildstep_git(c("clone",
#'                              "git@github.com:github_name/repo_name"))
#'      )
#'  )
#'
cr_buildstep_gitsetup <- function(keyring = "my-keyring",
                                  key = "github-key",
                                  cipher = "id_rsa.enc", ...){
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
    #TODO: pull in the host_file in inst/ssh/host_file
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
#' @family Cloud Buildsteps
#' @export
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
    volumes = git_volume()
  )
}

#' Create buildsteps for deploying an R pkgdown website to GitHub
#'
#' @inheritParams cr_buildstep
#' @inheritParams cr_buildstep_gitsetup
#' @param github_repo The GitHub repo to deploy pkgdown website from and to.
#' @param env A character vector of env arguments to set for all steps
#' @param git_email The email the git commands will be identifying as
#' @param build_image A docker image with \code{pkgdown} installed
#'
#' @details
#'
#' Its convenient to set some of the above via \link{Build} macros, such as \code{github_repo=$_GITHUB_REPO} and \code{git_email=$_BUILD_EMAIL} in the Build Trigger web UI
#'
#' @export
#' @family Cloud Buildsteps
#' @examples
#'
#' # github repo set via build trigger macro _GITHUB_REPO
#' cr_buildstep_pkgdown("$_GITHUB_REPO",
#'                      "cloudbuild@google.com")
#'
#' # example including environment arguments for pkgdown build step
#' steps <- cr_buildstep_pkgdown("$_GITHUB_REPO",
#'                      "cloudbuild@google.com",
#'                      env = c("MYVAR=$_MY_VAR", "PROJECT=$PROJECT_ID"))
#' build_yaml <- Yaml(steps = steps)
#' my_source <- cr_build_source(RepoSource("my_repo", branch="master"))
#' build <- cr_build_make(build_yaml, source = my_source)
cr_buildstep_pkgdown <- function(
           github_repo,
           git_email,
           keyring = "my-keyring",
           key = "github-key",
           env = NULL,
           cipher = "id_rsa.enc",
           build_image = 'gcr.io/gcer-public/packagetools:master'){

  pd <- system.file("cloudbuild/cloudbuild_pkgdown.yml",
                    package = "googleCloudRunner")


  # In yaml.load: NAs introduced by coercion: . is not a real
  pdb <- suppressWarnings(cr_build_make(pd))

  repo <- paste0("git@github.com:", github_repo)
  pkg <- cr_buildstep_extract(pdb, 4)
  pkg_env <- cr_buildstep_edit(pkg, env = env, dir = "repo")

  c(
    cr_buildstep_gitsetup(keyring = keyring,
                          key = key,
                          cipher = cipher),
    cr_buildstep_git(c("clone",repo, "repo")),
    pkg_env,
    cr_buildstep_git(c("add", "."), dir = "repo"),
    cr_buildstep_git(c("commit", "-a", "-m",
                       "[skip travis] Build website from commit ${COMMIT_SHA}: \
$(date +\"%Y%m%dT%H:%M:%S\")"),
                     dir = "repo"),
    cr_buildstep_git("push", repo, dir = "repo")
  )

}

git_volume <- function(){
  list(list(name = "ssh",
            path = "/root/.ssh"))
}

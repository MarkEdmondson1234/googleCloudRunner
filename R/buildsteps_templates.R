#' Send a Slack message to a channel from a Cloud Build step
#'
#' This uses https://github.com/technosophos/slack-notify to send Slack messages
#'
#' @param webhook The Slack webhook to send to
#' @param icon A URL to an icon (squares between 512px and 2000px)
#' @param channel The channel to send the message to (if omitted, use Slack-configured default)
#' @param title The title of the message
#' @param message The body of the message
#' @param colour The RGB colour for message formatting
#' @param username The name of the sender of the message. Does not need to be a "real" username
#'
#' @details
#'
#' You will need to set up a Slack webhook first, via this \href{https://api.slack.com/messaging/webhooks}{Slack guide on using incoming webhooks}.
#'
#' Once set, the default is to set this webhook to a Build macro called \code{_SLACK_WEBHOOK}, or supply it to the webhook argument.
#'
#' @examples
#' # send a message to googleAuthRverse Slack
#' webhook <-
#'  "https://hooks.slack.com/services/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"
#' cr_buildstep_slack("Hello Slack", webhook = webhook)
#'
#' \dontrun{
#'
#' bs <- cr_build_yaml(steps = cr_buildstep_slack("Hello Slack"))
#'
#' cr_build(bs, substitutions = list(`_SLACK_WEBHOOK` = webhook))
#'
#' }
#'
#' @family Cloud Buildsteps
#' @export
cr_buildstep_slack <- function(message,
                               title = "CloudBuild - $BUILD_ID",
                               channel = NULL,
                               username = "googleCloudRunnerBot",
                               webhook = "$_SLACK_WEBHOOK",
                               icon = NULL,
                               colour = "#efefef"){

  envs <- c(sprintf("SLACK_WEBHOOK=%s", webhook),
            sprintf("SLACK_MESSAGE='%s'", message),
            sprintf("SLACK_TITLE='%s'", title),
            sprintf("SLACK_COLOR='%s'", colour),
            sprintf("SLACK_USERNAME='%s'", username))

  if(!is.null(channel)){
    envs <- c(envs, sprintf("SLACK_CHANNEL=%s", channel))
  }

  if(!is.null(icon)){
    envs <- c(envs, sprintf("SLACK_ICON=%s", icon))
  }

  cr_buildstep(
    "technosophos/slack-notify",
    prefix = "",
    env = envs
  )

}


#' Setup nginx for Cloud Run in a buildstep
#'
#' @param html_folder The folder that will hold the HTML for Cloud Run
#'
#' This uses a premade bash script that sets up a Docker container ready for Cloud Run running nginx
#' @param ... Other arguments passed to \link{cr_buildstep_bash}
#'
#' @family Cloud Buildsteps
#' @export
#' @examples
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' cr_region_set("europe-west1")
#'
#' html_folder <- "my_html"
#' run_image <- "gcr.io/my-project/my-image-for-cloudrun"
#' cr_build_yaml(
#'  steps = c(
#'   cr_buildstep_nginx_setup(html_folder),
#'   cr_buildstep_docker(run_image, dir = html_folder),
#'   cr_buildstep_run(name = "running-nginx",
#'                    image = run_image,
#'                    concurrency = 80)
#'                    )
#'            )
cr_buildstep_nginx_setup <- function(html_folder, ...){

  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$args),
    is.null(dots$name),
    is.null(dots$prefix),
    is.null(dots$id)
  )

  bash_script <- system.file("docker", "nginx", "setup.bash",
                             package = "googleCloudRunner")
  cr_buildstep_bash(bash_script, dir = html_folder, id = "setup nginx", ...)

}



#' Send an email in a Cloud Build step via MailGun.org
#'
#' This uses Mailgun to send emails.  It calls an R script that posts the message to MailGuns API.
#'
#' @param message The message markdown
#' @param from from email
#' @param to to email
#' @param subject subject email
#' @param mailgun_url The Mailgun API base URL. Default assumes you set this in \link{Build} substitution macros
#' @param mailgun_key The Mailgun API key.  Default assumes you set this in \link{Build} substitution macros
#' @param ... Other arguments passed to \link{cr_buildstep_r}
#'
#' @details
#'
#' Requires an account at Mailgun: https://mailgun.com
#' Pre-verification you can only send to a whitelist of emails you configure - see Mailgun website for details.
#'
#' @family Cloud Buildsteps
#' @export
#' @examples
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' mailgun_url <- "https://api.mailgun.net/v3/sandboxXXX.mailgun.org"
#' mailgun_key <- "key-XXXX"
#'
#' \dontrun{
#' # assumes you have verified the email
#' cr_build(
#'   cr_build_yaml(steps = cr_buildstep_mailgun(
#'                            "Hello from Cloud Build",
#'                            to = "me@verfied_email.com",
#'                            subject = "Hello",
#'                            from = "googleCloudRunner@example.com"),
#'                 substitutions = list(
#'                   `_MAILGUN_URL` = mailgun_url,
#'                   `_MAILGUN_KEY` = mailgun_key)
#'           ))
#' }
cr_buildstep_mailgun <- function(message,
                               to,
                               subject,
                               from,
                               mailgun_url = "$_MAILGUN_URL",
                               mailgun_key = "$_MAILGUN_KEY",
                               ...){

  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$args),
    is.null(dots$name),
    is.null(dots$prefix)
  )

  r <- sprintf(
    'httr::POST(paste0("%s","/messages"),
           httr::authenticate("api", "%s"),
           encode = "form",
           body = list(
             from="%s",
             to="%s",
             subject="%s",
             text="%s"
           ))',
    mailgun_url, mailgun_key,
    from, to, subject, message
  )

  cr_buildstep_r(r,
                 id = "send mailgun",
                 name= "gcr.io/gcer-public/packagetools:master",
                 ...
                 )

}

#' Create buildsteps to deploy to Cloud Run
#'
#' @inheritParams cr_run
#' @param ... passed on to \link{cr_buildstep}
#' @export
#' @family Cloud Buildsteps
cr_buildstep_run <- function(name,
                             image,
                             allowUnauthenticated = TRUE,
                             region = cr_region_get(),
                             concurrency = 80,
                             ...){

  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$args),
    is.null(dots$name),
    is.null(dots$prefix),
    is.null(dots$id)
  )

  if(allowUnauthenticated){
    auth_calls <- "--allow-unauthenticated"
    #sometimes unauth fails, so attempt to fix as per warning suggestion
    auth_step <- cr_buildstep("gcloud",
                              c("run", "services", "add-iam-policy-binding",
                                "--region", region,
                                "--member=allUsers",
                                "--role=roles/run.invoker",
                                "--platform", "managed",
                                name),
                              id = "auth cloudrun",
                              ...)
  } else {
    auth_calls <- "--no-allow-unauthenticated"
    auth_step <- NULL
  }


  c(
    cr_buildstep("gcloud",
                   c("run","deploy", name,
                     "--image", image,
                     "--region", region,
                     "--platform", "managed",
                     "--concurrency", concurrency,
                     auth_calls
                   ),
                   id = "deploy cloudrun",
                 ...),
      auth_step
    )

}

#' Run a bash script in a Cloud Build step
#'
#' Helper to run a supplied bash script, that will be copied in-line
#'
#' @param bash_script bash code to run or a filepath to a file containing bash code that ends with .bash or .sh
#' @param name The image that will run the R code
#' @param bash_source Whether the code will be from a runtime file within the source or at build time copying over from a local file in your session
#' @param ... Other arguments passed to \link{cr_buildstep}
#' @family Cloud Buildsteps
#' @export
#'
#' @details
#'
#' If you need to escape build parameters in bash scripts, you need to escape CloudBuild's substitution via \code{$$} and bash's substitution via \code{\$} e.g. \code{\$$PARAM}
#'
#' @examples
#' cr_project_set("my-project")
#' bs <- cr_build_yaml(
#'   steps = cr_buildstep_bash("echo 'Hello'")
#'  )
#'
#' \dontrun{
#' cr_build(bs)
#' }
cr_buildstep_bash <- function(bash_script,
                              name = "ubuntu",
                              bash_source = c("local", "runtime"),
                              ...){

  bash_source <- match.arg(bash_source)

  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$args),
    is.null(dots$name),
    is.null(dots$prefix)
  )

  bchars <- read_buildstep_file(bash_script,
                                code_source = bash_source,
                                file_grep = "\\.(bash|sh)$")

  cr_buildstep(name = name,
               prefix = "",
               args = c("bash","-c", bchars),
               ...)
}

#' Run an R script in a Cloud Build R step
#'
#' Helper to run R code within build steps, from either an existing local R file or within the source of the build.
#'
#' @param r R code to run or a file containing R code ending with .R
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
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
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
#'                  "sessionInfo()"),
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

  # catches name=rocker/verse etc.
  if(dirname(name) == "rocker"){
     name <- basename(name)
  }

  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$args),
    is.null(dots$name),
    is.null(dots$prefix)
  )

  rchars <- read_buildstep_file(r,
                                code_source = r_source,
                                file_grep = "\\.R$")

  cr_buildstep(name = name,
               args = c("Rscript", "-e", rchars),
               prefix = prefix,
               ...)

}


read_buildstep_file <- function(x,
                                code_source = c("local","runtime"),
                                file_grep = ".*") {
  code_source <- match.arg(code_source)
  rchars <- x
  if(code_source == "local"){
    assert_that(is.character(x))

    rchars <- x
    if(grepl(file_grep, x[[1]], ignore.case = TRUE)){
      # filepath
      assert_that(is.readable(x), is.string(x))
      rchars <- readLines(x)
      myMessage("Copying into build step code from ", x, level = 2)
    }

    rchars <- paste(rchars, collapse = "\n")

  } else if(code_source == "runtime"){
    #filepath in source, not much we can do to check it
    myMessage("Will read code in source from filepath ", rchars, level = 3)
  }

  rchars
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
#'
#' Key Management Store can encrypt secret files for use within your later buildsteps.
#'
#' @section Setup:
#'
#' You will need to set up the \href{https://cloud.google.com/cloud-build/docs/securing-builds/use-encrypted-secrets-credentials}{encrypted key using gcloud} following the link from Google
#'
#' @family Cloud Buildsteps
#' @export
#' @examples
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
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
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#'
#' cr_buildstep_docker("gcr.io/my-project/my-image")
#' cr_buildstep_docker("my-image")
#' cr_buildstep_docker("my-image", tag = "$BRANCH_NAME")
#'
#' # setting up a build to trigger off a Git source:
#' my_image <- "gcr.io/my-project/my-image"
#' my_repo <- RepoSource("github_markedmondson1234_googlecloudrunner",
#'                       branchName="master")
#' \dontrun{
#' docker_yaml <- cr_build_yaml(steps = cr_buildstep_docker(my_image))
#' built_docker <- cr_build(docker_yaml, source = my_repo)
#'
#' # make a build trigger so it builds on each push to master
#' cr_buildtrigger("build-docker", trigger = my_repo, build = built_docker)
#' }
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
    is.null(dots$entrypoint),
    is.null(dots$id)
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
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#'
#' # assumes you have previously saved git ssh key via KMS called "git_key"
#' cr_build_yaml(
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
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' # github repo set via build trigger macro _GITHUB_REPO
#' cr_buildstep_pkgdown("$_GITHUB_REPO",
#'                      "cloudbuild@google.com")
#'
#' # example including environment arguments for pkgdown build step
#' steps <- cr_buildstep_pkgdown("$_GITHUB_REPO",
#'                      "cloudbuild@google.com",
#'                      env = c("MYVAR=$_MY_VAR", "PROJECT=$PROJECT_ID"))
#' build_yaml <- cr_build_yaml(steps = steps)
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
    cr_buildstep_git(c("add", "--all"), dir = "repo"),
    cr_buildstep_git(c("commit", "-a", "-m",
                       "[skip travis] Build website from commit ${COMMIT_SHA}: \
$(date +\"%Y%m%dT%H:%M:%S\")"),
                     dir = "repo"),
    cr_buildstep_git(c("status"), dir = "repo"),
    cr_buildstep_git("push", repo, dir = "repo")
  )

}

git_volume <- function(){
  list(list(name = "ssh",
            path = "/root/.ssh"))
}

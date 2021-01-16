#' Do R package tests and upload to Codecov
#'
#' This lets you run R package tests and is intended to be used in a trigger when you push to a repository so you can monitor code quality.
#'
#' @param codecov_token If using codecov, supply your codecov token here.
#' @param test_script The script that will perform tests.  If \code{NULL} a default script is used in \code{system.file("r_buildsteps", "devtools_tests.R")}
#' @param codecov_script The script that will perform coverage.  If \code{NULL} a default script is used in \code{system.file("r_buildsteps", "codecov_tests.R")}
#' @param build_image The docker image that will be used to run the R code for the test scripts
#' @param env Environment arguments to be set during the test script runs
#'
#' @export
#'
#' @examples
#'
#' cr_buildstep_packagetests()
#'
cr_buildstep_packagetests <- function(test_script = NULL,
                                      codecov_script = NULL,
                                      codecov_token = "$_CODECOV_TOKEN",
                                      build_image = "gcr.io/gcer-public/packagetools:latest",
                                      env = c("NOT_CRAN=true")){

  if(is.null(test_script)){
    test_script <- system.file("r_buildsteps", "devtools_tests.R",
                               package = "googleCloudRunner",
                               mustWork = TRUE)
  }


  test_bs <- cr_buildstep_r(
    test_script,
    name = build_image,
    env = env
  )

  codecov_bs <- NULL
  if(!is.null(codecov_token)){
    codecov_bs <- cr_buildstep_r(
      system.file("r_buildsteps", "codecov_tests.R",
                  package = "googleCloudRunner", mustWork = TRUE),
      name = build_image,
      env = c(env, paste0("CODECOV_TOKEN=", codecov_token))
    )
  }

  c(test_bs, codecov_bs)

}


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
                             port = NULL,
                             max_instances = "default",
                             memory = "256Mi",
                             cpu = 1,
                             env_vars = NULL,
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

  if(is.null(port)){
    port <- "default"
  }

  if(!is.null(env_vars)){
    env_vars <- paste0("--set-env-vars=", paste(env_vars, collapse = ","))
  } else {
    env_vars <- "--clear-env-vars"
  }

  c(
    cr_buildstep("gcloud",
                   c("beta","run","deploy", name,
                     "--image", image,
                     "--region", region,
                     "--platform", "managed",
                     "--concurrency", concurrency,
                     "--port", port,
                     "--max-instances", max_instances,
                     "--memory", memory,
                     "--cpu", cpu,
                     env_vars,
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

  # avoid having two bashes
  arg <- c("bash","-c", bchars)
  if(!is.null(dots$entrypoint) && dots$entrypoint == "bash"){
    arg <- c("-c", bchars)
  }

  cr_buildstep(name = name,
               prefix = "",
               args = arg,
               ...)
}

#' Run an R script in a Cloud Build R step
#'
#' Helper to run R code within build steps, from either an existing local R file or within the source of the build.
#'
#' @param r R code to run or a file containing R code ending with .R, or the gs:// location on Cloud Storage of the R file you want to run
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
#' If the R code location starts with \code{gs://} then an extra buildstep will be added that will download the R script from that location then run it as per \code{r_source="runtime"}.  This will consequently override your setting of \code{r_source}
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
#' br <-  cr_buildstep_r(my_r, name= "gcr.io/gcer-public/packagetools:latest")
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

  # ability to call R scripts from Cloud Storage
  if(grepl("^gs://", r[[1]])){
    r_here <- paste0("/workspace/", basename(r))
    myMessage(paste0("Buildstep will download R script from ", r),
              level = 3)
    gs <- c(
      cr_buildstep_gcloud(
        "gsutil",
        id = paste("download r script"),
        args = c("cp", r, r_here)
      ),
      cr_buildstep_r(
        r_here,
        name = name,
        r_source = "runtime",
        prefix = prefix,
        ...
      )
    )

    return(gs)

  }

  rchars <- read_buildstep_file(r,
                                code_source = r_source,
                                file_grep = "\\.R$")

  if(r_source == "local"){
    r_args <- c("Rscript", "-e", rchars)
  } else if(r_source == "runtime"){
    r_args <- c("Rscript", rchars)
  }

  cr_buildstep(name = name,
               args = r_args,
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

    # issue 103 - replace $ with $$ to avoid running as substitution vars
    rchars <- gsub("\\$","$$", rchars)

  } else if(code_source == "runtime"){
    #filepath in source, not much we can do to check it
    myMessage("Will read code in source from filepath ", rchars, level = 3)
  }

  if(nchar(rchars) == 0){
    stop("No code found to input into buildstep", call. = FALSE)
  }

  rchars
}



#' Create a build step for decrypting files via KMS
#'
#' Create a build step to decrypt files using CryptoKey from Cloud Key Management Service.
#' Usually you will prefer to use \link{cr_buildstep_secret}
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
#' You will need to set up the \href{https://cloud.google.com/cloud-build/docs/securing-builds/use-encrypted-secrets-credentials#encrypt_credentials}{encrypted key using gcloud} following the link from Google
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

#' Create a buildstep for using Secret Manager
#'
#' This is the preferred way to manage secrets, rather than
#'   \link{cr_buildstep_decrypt}, as it stores the encrypted file in the cloud
#'   rather than in your project workspace.
#'
#' @seealso How to set up secrets using \href{https://cloud.google.com/cloud-build/docs/securing-builds/use-encrypted-secrets-credentials}{Secret Manager}
#'
#' @param secret The secret data name in Secret Manager
#' @param decrypted The name of the file the secret will be decrypted into
#' @param version The version of the secret
#' @param ... Other arguments sent to \link{cr_buildstep_bash}
#'
#' @details
#'
#' This is for downloading encrypted files from Google Secret Manager.  You will need to add the
#'   Secret Accessor Cloud IAM role to the Cloud Build service account to use it.
#' Once you have uploaded your secret file and named it, it is available for Cloud
#'   Build to use.
#' @family Cloud Buildsteps
#' @export
#' @examples
#' cr_buildstep_secret("my_secret", decrypted = "/workspace/secret.json")
#'
cr_buildstep_secret <- function(secret,
                                decrypted,
                                version = "latest",
                                ...){

  script <- sprintf("gcloud secrets versions access %s --secret=%s > %s",
    version, secret, decrypted
  )

  cr_buildstep(
    args = c("-c", script),
    name = "gcr.io/cloud-builders/gcloud",
    entrypoint = "bash",
    ...
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
#' @param post_clone A \link{cr_buildstep} that occurs after the repo is cloned
#'
#' @details
#'
#' Its convenient to set some of the above via \link{Build} macros, such as \code{github_repo=$_GITHUB_REPO} and \code{git_email=$_BUILD_EMAIL} in the Build Trigger web UI
#'
#' To commit the website to git, \link{cr_buildstep_gitsetup} is used for which
#'   you will need to add your git ssh private key to Google Secret Manager
#'
#' The R package is installed via \link[devtools]{install} before
#'   running \link[pkgdown]{build_site}
#'
#' @export
#' @family Cloud Buildsteps
#' @examples
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#'
#' # set github repo directly to write it out via cr_build_write()
#' cr_buildstep_pkgdown("MarkEdmondson1234/googleCloudRunner",
#'                      git_email = "cloudbuild@google.com",
#'                      secret = "github-ssh")
#'
#' # github repo set via build trigger macro _GITHUB_REPO
#' cr_buildstep_pkgdown("$_GITHUB_REPO",
#'                      git_email = "cloudbuild@google.com",
#'                      secret = "github-ssh")
#'
#' # example including environment arguments for pkgdown build step
#' cr_buildstep_pkgdown("$_GITHUB_REPO",
#'                      git_email = "cloudbuild@google.com",
#'                      secret = "github-ssh",
#'                      env = c("MYVAR=$_MY_VAR", "PROJECT=$PROJECT_ID"))
#'
cr_buildstep_pkgdown <- function(
           github_repo,
           git_email,
           secret,
           env = NULL,
           build_image = "gcr.io/gcer-public/packagetools:latest",
           post_setup = NULL,
           post_clone = NULL){

  repo <- paste0("git@github.com:", github_repo)

  c(
    cr_buildstep_gitsetup(secret, post_setup = post_setup),
    cr_buildstep_git(c("clone",repo, "repo"), id = "clone to repo dir"),
    post_clone,
    cr_buildstep_r(c("devtools::install_deps(dependencies=TRUE)",
                     "devtools::install_local()",
                     "pkgdown::build_site()"),
                   name = build_image,
                   dir = "repo",
                   env = env,
                   id = "build pkgdown"),
    cr_buildstep_git(c("add", "--all"), dir = "repo"),
    cr_buildstep_git(c("commit", "-a", "-m",
                       "[skip travis] Build website from commit ${COMMIT_SHA}: \
$(date +\"%Y%m%dT%H:%M:%S\")"),
                     dir = "repo"),
    cr_buildstep_git("status", dir = "repo"),
    cr_buildstep_git("push", dir = "repo")
  )

}

#' A buildstep template for gcloud
#'
#' This enables an optimised version of gcloud docker for your buildstep such as \code{gcr.io/google.com/cloudsdktool/cloud-sdk:alpine}
#'
#' @seealso \url{https://github.com/GoogleCloudPlatform/cloud-builders/tree/master/gcloud}
#' @param component What gcloud service you need, such as "gcloud", "bq" or "gsutil"
#' @param ... Other arguments passed to \link{cr_buildstep}
#' @inheritDotParams cr_buildstep
#'
#' @export
#' @family Cloud Buildsteps
#' @import assertthat
cr_buildstep_gcloud <- function(component = c("gcloud","bq","gsutil","kubectl"),
                                ...){

  component <- match.arg(component)

  # don't allow dot names that would break things
  dots <- list(...)
  assert_that(
    is.null(dots$name),
    is.null(dots$prefix),
    is.null(dots$entrypoint)
  )

  the_name <- "cloud-sdk:alpine"
  if(component == "kubectl"){
    the_name <- "cloud-sdk:latest"
  }

  entrypoint <- NULL
  if(component != "gcloud"){
    entrypoint <- component
  }

  cr_buildstep(
    name = the_name,
    prefix = "gcr.io/google.com/cloudsdktool/",
    entrypoint = entrypoint,
    ...
  )

}


#' A helper setup function for setting up use with googleCloudRunner
#'
#'
#' @export
#' @import cli
#' @importFrom utils menu packageVersion
#' @family setup functions
cr_setup <- function(){

  cli_alert_info(sprintf("==Welcome to googleCloudRunner v%s setup==",
                  packageVersion("googleCloudRunner")))

  if(!interactive()){
    stop("Can only be used in an interactive R session", call. = FALSE)
  }

  ready <- menu(title = "This wizard will scan your system for setup options and help you with any that are missing. \nHit 0 or ESC to cancel.",
                choices = c(
                  "Configure/check all googleCloudRunner settings",
                  "Configure GCP Project Id",
                  "Configure Authentication JSON file",
                  "Configure Cloud Storage bucket",
                  "Configure Cloud Run region",
                  "Configure Cloud Scheduler build email",
                  "Configure Cloud Build service account"
                ))

  if(ready == 0){
    return(invisible(""))
  }
  cli_rule()
  session_user <- check_session()

  cli_rule()
  project_id <- NULL
  if(ready %in% c(1,2)){
    project_id <- do_env_check("GCE_DEFAULT_PROJECT_ID",
                               not_present = get_project_setup(),
                               ready = ready,
                               session_user = session_user)
    # stop if project_id not configured
    if(ready > 1 || !project_id) return(invisible(""))
  }

  cli_rule()
  auth_file <- NULL
  if(ready %in% c(1,3)){
    auth_file  <- do_env_check("GCE_AUTH_FILE",
                               not_present = get_auth_setup(session_user),
                               ready = ready,
                               session_user = session_user)
    # stop if auth_file not configured
    if(ready > 1 || !auth_file) return(invisible(""))
  }

  cli_rule()
  bucket <- NULL
  if(ready %in% c(1,4)){
    bucket     <- do_env_check("GCS_DEFAULT_BUCKET",
                               not_present = get_bucket_setup(),
                               ready = ready,
                               session_user = session_user)
  }
  cli_rule()
  region <- NULL
  if(ready %in% c(1,5)){
    region     <- do_env_check("CR_REGION",
                               not_present = get_region_setup(),
                               ready = ready,
                               session_user = session_user)
  }
  cli_rule()
  email <- NULL
  if(ready %in% c(1,6)){
    email      <- do_env_check("CR_BUILD_EMAIL",
                               not_present = get_email_setup(),
                               ready = ready,
                               session_user = session_user)
  }
  cli_rule()

  if(ready %in% c(1,7)){
    service_email <- do_build_service_setup()
  }
  cli_rule()

  if(all(email, region, bucket, auth_file, project_id, service_email)){
    cli_alert_success("Setup complete! You can test it with cr_setup_test()")
  }

  cli_alert_info("Some setup still to complete.
                 Restart R and/or rerun cr_setup() when ready")

}




#' @noRd
#' @return TRUE once changes made
#' @param env_arg The environment argument to check
#' @param not_present NULL or a string to set in .Renviron
#' @param ready Menu option !=1 means editing existing
#' @param session_user 1=user, 2=project scope of .Renviron
do_env_check <- function(env_arg,
                         not_present,
                         ready,
                         session_user){
  arg <- Sys.getenv(env_arg)

  if(arg == ""){
    cli_alert_info("No environment argument detected: {env_arg}")
  } else if(ready != 1) {
    cli_alert_info("Editing environment argument: {env_arg}={arg}")
  } else {
    cli_alert_success("Found: {env_arg}={arg}")
    return(TRUE)
  }

  if(!is.null(not_present)){
    assert_that(is.string(not_present))
  }

  # NULL if no setting could be found
  attempt_setting <- not_present

  if(!is.null(attempt_setting)){
    edit_renviron(not_present, session_user = session_user)
    return(TRUE)
  }

  FALSE

}



edit_renviron <- function(to_paste, session_user){

  if(session_user == 1){
    scope <- "user"
  } else if(session_user == 2){
    scope <- "project"
  } else {
    stop("User cancelled setup", call. = FALSE)
  }
  cli_ul("Configuring your .Renviron...")
  cli_code(to_paste)
  add_renviron(scope = scope, line = to_paste)
  cli_alert_success("Restart R and run the wizard again to check configuration")
}

add_renviron <- function(scope = c("user", "project"), line){
  the_file <- switch(
    scope,
    user = file.path(Sys.getenv("HOME"), ".Renviron"),
    project = file.path(rstudioapi::getActiveProject(), ".Renviron")
  )

  if(!file.exists(the_file)){
    file.create(the_file)
  }

  add_line(line, the_file)
}

## from https://github.com/hadley/httr/blob/4624451f8cc395a90730b5a10b50ba005187f2ff/R/oauth-cache.R
add_line <- function(line, path, quiet = TRUE) {
  if(is.null(line)) return(TRUE)

  if (file.exists(path)) {
    lines <- readLines(path, warn = FALSE)
    lines <- lines[lines != ""]
  } else {
    lines <- character()
  }

  if (line %in% lines) return(TRUE)
  if (!quiet) message("Adding ", line, " to ", path)

  lines <- c(lines, line)
  writeLines(lines, path)
  TRUE
}

check_session <- function(){
  session_user <- menu(title = "Do you want to configure for all R sessions or just this project?",
                       choices = c("All R sessions (Recommended)", "Project only"))
  if(session_user == 2){
    local_file <- file.path(rstudioapi::getActiveProject(), ".Renviron")
    if(!file.exists(local_file)){
      file.create(local_file)
      stop("Restart R to enable local project .Renviron", call. = FALSE)
    }
  }

  session_user
}

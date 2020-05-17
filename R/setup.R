#' A helper setup function for setting up use with googleCloudRunner
#'
#'
#' @export
#' @import cli googleAuthR
#' @importFrom utils menu packageVersion
#' @family setup functions
cr_setup <- function(){

  op <- gar_setup_menu(choices = c(
      "Configure/check all googleCloudRunner settings",
      "Configure GCP Project Id",
      "Configure Authentication JSON file",
      "Configure Cloud Storage bucket",
      "Configure Cloud Run region",
      "Configure Cloud Scheduler build email",
      "Configure Cloud Build service account"),
    package_name = "googleCloudRunner"
  )

  session_user <- gar_setup_check_session()

  we_edit <- op != 1
  project_id <- gar_setup_menu_do(op,
                                  trigger = c(1,2),
                                  do_function = gar_setup_env_check,
                                  stop = TRUE,
                                  env_arg = "GCE_DEFAULT_PROJECT_ID",
                                  set_to = get_project_setup(),
                                  edit_option = we_edit,
                                  session_user = session_user)


  if(we_edit) return(invisible(""))

  cli_rule()

  session_user <- check_session()

  cli_rule()

  auth_file <- gar_setup_menu_do(op,
                                 trigger = c(1,3),
                                 do_function = gar_setup_env_check,
                                 env_arg = "GCE_AUTH_FILE",
                                 set_to = get_auth_setup,
                                 edit_option = we_edit,
                                 stop = TRUE,
                                 session_user = session_user)

  if(we_edit) return(invisible(""))

  cli_rule()

  bucket <- gar_setup_menu_do(op,
                              trigger = c(1,4),
                              do_function = gar_setup_env_check,
                              env_arg = "GCS_DEFAULT_BUCKET",
                              set_to = get_bucket_setup(),
                              edit_option = we_edit,
                              session_user = session_user
                              )
  if(we_edit) return(invisible(""))
  cli_rule()

  region <- gar_setup_menu_do(op,
                              trigger = c(1,5),
                              do_function = gar_setup_env_check,
                              env_arg = "CR_REGION",
                              set_to = get_region_setup(),
                              edit_option = we_edit,
                              session_user = session_user)
  if(we_edit) return(invisible(""))
  cli_rule()

  email <- gar_setup_menu_do(op,
                             trigger = c(1,6),
                             do_function = gar_setup_env_check,
                             env_arg = "CR_BUILD_EMAIL",
                             set_to = get_email_setup(),
                             edit_option = we_edit,
                             session_user = session_user)
  if(we_edit) return(invisible(""))
  cli_rule()

  gar_setup_menu_do(op,trigger = 7,do_function = do_build_service_setup)

  if(we_edit) return(invisible(""))
  cli_rule()


  if(all(email, region, bucket, auth_file, project_id)){
    cli_alert_success("Setup complete! You can test it with cr_setup_test()")
    cli_rule()
    return(invisible(""))
  }

  cli_alert_info("Some setup still to complete.
                 Restart R and/or rerun cr_setup() when ready")

  cli_rule()

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

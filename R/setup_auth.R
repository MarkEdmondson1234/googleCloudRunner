#' Create a service account for googleCloudRunner
#'
#' This will use your Google OAuth2 user to create a suitable service account
#'
#' @param email What email to open OAuth2 with
#' @param file Where to save the authentication file
#' @param session_user 1 for user level, 2 for project level, leave \code{NULL} to be prompted
#'
#' @return TRUE if the file is ready to be setup by \link{cr_setup}, FALSE if need to stop
#'
#' @export
#' @importFrom googleAuthR gar_service_provision
#' @import cli
#' @family setup functions
cr_setup_auth <- function(email = Sys.getenv("GARGLE_EMAIL"),
                          file = "googlecloudrunner-auth-key.json",
                          session_user = NULL){

  if(is.null(session_user)){
    session_user <- check_session()
  }

  if(Sys.getenv("GAR_CLIENT_JSON") == ""){
    cli_alert_info("Could not find a OAuth 2.0 Client ID via GAR_CLIENT_JSON")

    client_id <- usethis::ui_yeah("Have you downloaded a Client ID file?",
                                  yes = "Yes", no = "No")

    if(!client_id){
      cli_alert_warning("You must have a client ID file to proceed.")
      cli_alert_info("Download via https://console.cloud.google.com/apis/credentials/oauthclient :")
      cli_li(c("Other > Name > Create >",
               "OAuth 2.0 Client IDs >",
               "Click Download Arrow to the right >",
               "Download to your computer"))
      cli_rule()
      cli_alert_info("Rerun this wizard once you have your Client ID file")
      if(usethis::ui_yeah("Open up service credentials URL?")){
        utils::browseURL("https://console.cloud.google.com/apis/credentials/oauthclient")
      }
      return(FALSE)
    }

    ff <- usethis::ui_yeah("Select location of your client ID file:",
                           yes = "Ready", no = "Cancel")

    if(!ff){
      return(FALSE)
    }

    json <- file.choose()
    valid <- validate_json(json)

    if(valid){
      edit_renviron(paste0("GAR_CLIENT_JSON=",json), session_user = session_user)
    }
    # we always return that cr_setup() needs to be rerun
    return(FALSE)

  }

  cli_alert_info("Using Client ID via GAR_CLIENT_JSON")
  cli_rule()
  json <- Sys.getenv("GAR_CLIENT_JSON")
  if(!validate_json(json)){
    return(FALSE)
  }

  create_service <- usethis::ui_yeah("Client ID present but no service authentication file is configured.  Do you want to provision a service account for your project?",
                                     yes = "Yes, I need a service account key",
                                     no = "No, I already have one downloaded")

  if(!create_service){
    cli_alert_danger("No service account provisioned, using existing")
    return(TRUE)
  }

  roles <- cr_setup_role_lookup("local")

  cli_alert_info("Creating service key file - choose service account name (Push enter for default 'googlecloudrunner')")
  account_id <- readline("service account name: ")
  if(account_id == ""){
    account_id <- "googlecloudrunner"
  }

  cli_alert_info("Creating service account {account_id}")

  gar_service_provision(
    account_id,
    roles = roles,
    json = json,
    file = file,
    email = email)

  cli_alert_success("Move {file} to a secure folder location outside of your working directory")
  moved <- usethis::ui_yeah("Have you moved the file?")
  if(!moved){
    cli_alert_danger("Beware! Authentication files can be used to compromise your GCP account. Do not check into git or otherwise share the file")
    return(FALSE)
  }

  cli_alert_success("Service JSON key is now created")
  cli_alert_info("Configuring GCE_AUTH_FILE to point at service JSON key")

  TRUE

}

validate_json <- function(json){
  validated <- tryCatch(jsonlite::fromJSON(json),
                        error = function(err){
                          cli::cli_alert_danger("Could not load alleged Client ID file: {err$message}")
                          return(FALSE)
                        })
  if(!is.null(validated$installed$client_id)){
    cli::cli_alert_success("Validated Client ID file {json}")
    cli::cli_alert_success("Found Client ID project: {validated$installed$project_id}")
    return(TRUE)
  } else {
    cli::cli_alert_danger("Could not read details from client ID file - is it the right one?")
    return(FALSE)
  }

}

extract_project_number <- function(json = Sys.getenv("GAR_CLIENT_JSON")){
  gsub("^([0-9]+?)\\-(.+)\\.apps.+","\\1",jsonlite::fromJSON(json)$installed$client_id)
}

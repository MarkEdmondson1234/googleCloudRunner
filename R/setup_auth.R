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
#' @importFrom googleAuthR gar_setup_auth_key
#' @import cli
#' @family setup functions
cr_setup_auth <- function(email = Sys.getenv("GARGLE_EMAIL"),
                          file = "googlecloudrunner-auth-key.json",
                          session_user = NULL) {
  gar_setup_auth_key(
    email = email,
    file = file,
    session_user = session_user,
    client_json = "GAR_CLIENT_JSON",
    roles = cr_setup_role_lookup("local"),
    default_key = "googlecloudrunner"
  )
}

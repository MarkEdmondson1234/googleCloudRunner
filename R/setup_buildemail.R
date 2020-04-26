#' Give a service account the right permissions for googleCloudRunner operations
#'
#' @param account_email The service account email e.g. \code{accountId@projectid.iam.gserviceaccount.com}
#' @param json the project clientId JSON
#' @param email the email of an Owner/Editor for the project
#' @param roles the roles to grant access - default is all googleCloudRunner functions
#'
#' @export
#' @import googleAuthR
cr_setup_service <- function(account_email,
                             json = Sys.getenv("GAR_CLIENT_JSON"),
                             email = Sys.getenv("GARGLE_EMAIL"),
                             roles = c("roles/cloudbuild.builds.builder",
                                       "roles/secretmanager.secretAccessor",
                                       "roles/cloudscheduler.admin",
                                       "roles/iam.serviceAccountUser",
                                       "roles/run.admin",
                                       "roles/storage.admin")){

  projectId <- gar_set_client(json,
                  scopes = "https://www.googleapis.com/auth/cloud-platform")
  if(email == ""){
    email <- NULL
  }
  gar_auth(email = email)

  gar_service_grant_roles(account_email,
                          roles = roles,
                          projectId = projectId)
}

cr_role_lookup <- function(type = c(
  "googleCloudRunner-local",
  "bigquery",
  ""
)){

  local_roles <- c("roles/cloudbuild.builds.builder",
                   "roles/secretmanager.secretAccessor",
                   "roles/cloudscheduler.admin",
                   "roles/iam.serviceAccountUser",
                   "roles/run.admin",
                   "roles/storage.admin")


}

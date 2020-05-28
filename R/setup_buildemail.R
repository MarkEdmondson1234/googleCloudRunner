#' Give a service account the right permissions for googleCloudRunner operations
#'
#' @param account_email The service account email e.g. \code{accountId@projectid.iam.gserviceaccount.com} or {12345678@cloudbuild.gserviceaccount.com}
#' @param json the project clientId JSON
#' @param email the email of an Owner/Editor for the project
#' @param roles the roles to grant access - default is all googleCloudRunner functions
#'
#' @export
#' @import googleAuthR
#' @family setup functions
cr_setup_service <- function(account_email,
                             roles = cr_setup_role_lookup("local"),
                             json = Sys.getenv("GAR_CLIENT_JSON"),
                             email = Sys.getenv("GARGLE_EMAIL")
                             ){

  projectId <- gar_set_client(json,
                  scopes = "https://www.googleapis.com/auth/cloud-platform")
  if(email == ""){
    email <- NULL
  }
  gar_auth(email = email)

  gar_service_grant_roles(trimws(account_email),
                          roles = roles,
                          projectId = projectId)

  the_roles <- NULL
  the_roles <- paste(roles, collapse = " ")
  cli_alert_success("Configured {account_email} with roles: {the_roles}")
}


#' @param type the role
#' @export
#' @rdname cr_setup_service
cr_setup_role_lookup <- function(type = c(
  "local",
  "cloudrun",
  "bigquery",
  "secrets",
  "cloudbuild",
  "cloudstorage",
  "schedule_agent",
  "run_agent"
)){

  type <- match.arg(type)

  switch(type,
         local = c("roles/cloudbuild.builds.builder",
                   "roles/secretmanager.secretAccessor",
                   "roles/cloudscheduler.admin",
                   "roles/iam.serviceAccountUser",
                   "roles/run.admin",
                   "roles/storage.admin"),
         cloudrun = c("roles/run.admin",
                      "roles/iam.serviceAccountUser",
                      "roles/serverless.serviceAgent"),
         bigquery = "roles/bigquery.admin",
         secrets = "roles/secretmanager.secretAccessor",
         cloudbuild = c("roles/cloudbuild.builds.builder",
                        "roles/iam.serviceAccountUser"),
         cloudstorage = "roles/storage.admin",
         schedule_agent = "roles/cloudscheduler.serviceAgent",
         run_agent = "roles/serverless.serviceAgent"
         )



}

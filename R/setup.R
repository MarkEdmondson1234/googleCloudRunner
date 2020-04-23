#' A helper setup function for setting up use with googleCloudRunner
#'
#'
#' @export
#' @import cli
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
                  "Configure Cloud Scheduler build email"
                ))

  if(ready == 0){
    return(invisible(""))
  }

  project_id <- NULL
  if(ready %in% c(1,2)){
    project_id <- do_env_check("GCE_DEFAULT_PROJECT_ID",
                               get_project_setup(),
                               ready)
    if(is.null(project_id) && ready > 1) return(invisible(""))
  }

  auth_file <- NULL
  if(ready %in% c(1,3)){
    auth_file  <- do_env_check("GCE_AUTH_FILE",
                               get_auth_setup(),
                               ready)
    if(is.null(auth_file) && ready > 1) return(invisible(""))
  }

  bucket <- NULL
  if(ready %in% c(1,4)){
    bucket     <- do_env_check("GCS_DEFAULT_BUCKET",
                               get_bucket_setup(),
                               ready)
  }

  region <- NULL
  if(ready %in% c(1,5)){
    region     <- do_env_check("CR_REGION",
                               get_region_setup(),
                               ready)
  }

  email <- NULL
  if(ready %in% c(1,6)){
    email      <- do_env_check("CR_BUILD_EMAIL",
                               get_email_setup(auth_file$auth_file),
                               ready)
  }

  to_paste <- c(project_id,
                auth_file$env_arg,
                bucket,
                region,
                email)

  if(!is.null(to_paste)){
    cli_ul("Include this code in your .Renviron to set for all future R sessions")
    cli_code(to_paste)
    usethis::edit_r_environ()
    cli_ul("Rerun cr_setup() once complete to check settings")
    return(invisible(""))
  }

  cli_alert_success("Setup complete!")

}

get_email_setup <- function(auth_file){
  email <- usethis::ui_yeah("Do you want to setup a Cloud Scheduler email?")
  if(email){
    reuse_auth <- usethis::ui_yeah("Do you want to use the email from your JSON service account auth key?")
    if(reuse_auth){
      if(Sys.getenv("GCE_AUTH_FILE") == ""){
        cli_alert_info("You need to setup the auth environment argument before configuring an email from it.  Rerun the wizard once it is setup")
        return(NULL)
      }

      the_email <- jsonlite::fromJSON(auth_file)$client_email
    } else {
      the_email <- readline("Enter the service email you wish to use")
    }

    cli_alert_info("Using email: {the_email}")
    return(paste0("CR_BUILD_EMAIL=", the_email))

  }

  cli_alert_danger("Cloud Scheduler (cr_schedule()) functionality will not be available
          unless an email is specified via cr_email_set()")

  NULL

}

get_region_setup <- function(){
  region <- usethis::ui_yeah("Do you want to setup a Cloud Run region?")
  if(region){
    choices <- c("us-central1",
                 "asia-northeast1",
                 "europe-west1",
                 "us-east1")
    region_select <- menu(
      choices = choices,
      title = "Which region shall Cloud Run perform in?"
    )
    if(region_select > 0){
      the_region <- choices[[region_select]]
      cli_alert_success(paste("Selected region:", the_region))
      return(paste0("CR_REGION=", the_region))
    } else {
      cli_alert_danger("No region selected")
    }

  }

  cli_alert_danger("Cloud Run (cr_run_*) functionality will not be available
          unless a region is configured via cr_region_set()")

  NULL

}

get_bucket_setup <- function(){

  if(Sys.getenv("GCE_AUTH_FILE") == ""){
    cli_alert_info("You need to setup the auth environment argument before configuring a bucket.  Rerun the wizard once it is setup")
    return(NULL)
  }

  bucket <- usethis::ui_yeah("Do you want to setup a Cloud Storage bucket?")
  if(bucket){
    has_bucket <- usethis::ui_yeah("Do you have an existing Cloud Storage bucket you want to use?")
    if(has_bucket){
      the_bucket <- readline("What is the name of your bucket? e.g. my-bucket-name: ")
      check_bucket <- tryCatch(
        googleCloudStorageR::gcs_get_bucket(the_bucket),
        error = function(err){
          cli_alert_danger("Could not get bucket: {err$message}")
          return(NULL)
        })
      if(!is.null(check_bucket$kind) && check_bucket$kind == "storage#bucket"){
        cli_alert_info("Validated Cloud Storage bucket")
        return(paste0("GCS_DEFAULT_BUCKET=", the_bucket))
      } else {
        cli_alert_danger("Invalid bucket: {the_bucket}")
        return(NULL)
      }

    } else {
      make_bucket <- usethis::ui_yeah("Do you want to make a new Cloud Storage bucket?")
      if(make_bucket){
        if(Sys.getenv("GCE_DEFAULT_PROJECT_ID") == ""){
          cli_alert_info("You need to setup a project-id before creating a bucket")
          return(NULL)
        }
        make_bucket_name <- readline(
    paste("What name will the bucket be? It will be created in your project: ",
          cr_project_get())
          )
        new_bucket <- googleCloudStorageR::gcs_create_bucket(
          make_bucket_name, projectId = cr_project_get()
        )
        if(!is.null(new_bucket$kind) && new_bucket$kind == "storage#bucket"){
          cli_alert_success("Successfully created bucket {make_bucket_name}")
          return(paste0("GCS_DEFAULT_BUCKET=", new_bucket))
        }

      } else {
        cli_ul("No bucket set")
      }
    }
  }

  cli_alert_danger("Some Cloud Build (cr_build_*) functionality will not be available
          with a bucket unless configured via cr_bucket_set()")

  NULL
}

get_auth_setup <- function(){

  auth <- cr_setup_auth()

  if(auth){
    cli_ul("Browse to the file to be used for authentication")
    auth_file <- file.choose()
    check_file <- tryCatch(jsonlite::fromJSON(auth_file),
                           error = function(err){
                             cli_alert_danger("Could not read JSON file: {auth_file}")
                             NULL})
    if(!is.null(check_file$type) &&
       check_file$type == "service_account" &&
       !is.null(check_file$private_key)){
      cli_alert_success("Validated authentication JSON file")
      return(list(env_arg = paste0("GCE_AUTH_FILE=", auth_file),
                  auth_file = auth_file))
    }

    cli_alert_danger("Checked {auth_file} and it was not a valid JSON file? Confirm file is JSON service account auth key - see website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")

  }

  cli_ul("Run cr_setup_auth()")

  cli_ul("See website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")

  NULL

}

get_project_setup <- function(){
  project <- usethis::ui_yeah("Do you have a Google Cloud project-id to use?")
  if(project){
    project_id <- readline("project-id: ")
    cli_alert_success("Selected project-id: {project_id}")
    return(paste0("GCE_DEFAULT_PROJECT_ID=",project_id))
  }

  cli_ul("Create a Google Cloud Project with billing attached and get its project-id.  Re-do this wizard when you have one or use cr_project_set()")

  cli_ul("Visit https://cloud.google.com/docs/overview to get started")

  NULL
}

do_env_check <- function(env_arg,
                         not_present,
                         ready){
  arg <- Sys.getenv(env_arg)
  if(arg == ""){
    cli_alert_info("No environment argument detected: {env_arg}")
    return(not_present)
  } else if(ready != 1) {
    cli_alert_info("Editing environment argument: {env_arg}={arg}")
    return(not_present)
  } else {
    cli_alert_success("Found: {env_arg}={arg}")
  }
  NULL
}

#' Create a service account for googleCloudRunner
#'
#' This will use your Google OAuth2 user to create a suitable service account
#'
#' @param email What email to open OAuth2 with
#' @param file Where to save the authentication file
#' @param accountId Name of the service account in GCP IAM
#'
#' @return TRUE if the file is ready to be setup by \link{cr_setup}
#'
#' @export
#' @importFrom googleAuthR gar_service_provision
#' @import cli
cr_setup_auth <- function(email = Sys.getenv("GARGLE_EMAIL"),
                          file = "googlecloudrunner-auth-key.json",
                          accountId = "googlecloudrunner"){

  if(Sys.getenv("GAR_CLIENT_JSON") == ""){
    cli_alert_info("Could not find a OAuth 2.0 Client ID via GAR_CLIENT_JSON")

    client_id <- usethis::ui_yeah("Have you downloaded a JSON Client ID from your GCP?")

    if(!client_id){
      cli_alert_info("Download via https://console.cloud.google.com/apis/credentials")
      cli_ul(c("Sidebar Menu >",
                    "APIs & Services >",
                    "Credentials >",
                    "+ Create Credentials",
                    "OAuth client ID >",
                    "Other >",
                    "Download to your PC"))
      cli_alert_info("Rerun this wizard once you have your Client ID file")
      return(FALSE)
    }

    cli_alert_info("Where is your client ID file?")
    json <- file.choose()
    valid <- validate_json(json)

    if(valid){
      cli_alert_success(
          "Validated Client ID file {json} for project: {validated$installed$project_id}")
      cli_ul("Include this code in your .Renviron to set client ID for all future R sessions")
      cli_code(paste0("GAR_CLIENT_JSON=",json))
      usethis::edit_r_environ()
        cli_ul("Rerun this wizard once .Renviron is updated and R restarted")
    }
    # we always return that cr_setup() needs to be rerun
    return(FALSE)

  }

  cli_alert_info("Using Client ID via GAR_CLIENT_JSON")
  json <- Sys.getenv("GAR_CLIENT_JSON")
  if(!validate_json(json)){
    return(FALSE)
  }

  create_service <- usethis::ui_yeah("Do you want to provision a service account?")

  if(!create_service){
    cli_alert_danger("No service account provisioned")
    return(TRUE)
  }

  roles <- c("roles/cloudbuild.builds.builder",
             "roles/secretmanager.secretAccessor",
             "roles/cloudscheduler.admin",
             "roles/iam.serviceAccountUser",
             "roles/run.admin",
             "roles/storage.admin")

  cli_alert_info("Creating service key file")

  gar_service_provision(
        accountId,
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

  cli_alert_success("Service JSON key is now provisioned")
  cli_alert_info("Now set up GCE_AUTH_FILE to point at file via cr_setup()")

  TRUE

}

validate_json <- function(json){
  validated <- tryCatch(jsonlite::fromJSON(json),
      error = function(err){
        cli::cli_alert_danger("Could not load alleged Client ID file: {err$message}")
        return(FALSE)
      })
  if(!is.null(validated$installed$client_id)){
    cli::cli_alert_success(
      "Validated Client ID file {json} for project: {validated$installed$project_id}")
    return(TRUE)
  } else {
    cli::cli_alert_danger("Could not read details from client ID file - is it the right one?")
    return(FALSE)
  }

}


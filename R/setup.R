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
  cli_rule()
  project_id <- NULL
  if(ready %in% c(1,2)){
    project_id <- do_env_check("GCE_DEFAULT_PROJECT_ID",
                               get_project_setup(),
                               ready)
    if(is.null(project_id) || ready > 1) return(invisible(""))
  }
  cli_rule()
  auth_file <- NULL
  if(ready %in% c(1,3)){
    auth_file  <- do_env_check("GCE_AUTH_FILE",
                               get_auth_setup(),
                               ready)
    if(is.null(auth_file) || ready > 1) return(invisible(""))
  }
  cli_rule()
  bucket <- NULL
  if(ready %in% c(1,4)){
    bucket     <- do_env_check("GCS_DEFAULT_BUCKET",
                               get_bucket_setup(),
                               ready)
  }
  cli_rule()
  region <- NULL
  if(ready %in% c(1,5)){
    region     <- do_env_check("CR_REGION",
                               get_region_setup(),
                               ready)
  }
  cli_rule()
  email <- NULL
  if(ready %in% c(1,6)){
    email      <- do_env_check("CR_BUILD_EMAIL",
                               get_email_setup(),
                               ready)
  }
  cli_rule()
  to_paste <- as.character(c(project_id,
                             auth_file,
                             bucket,
                             region,
                             email))
  # only paste entries with characters, not TRUE or NULL
  to_paste <- to_paste[to_paste != "TRUE"]

  if(length(to_paste) > 0){

    edit_renviron(to_paste)

    cli_ul("Rerun cr_setup() once complete to check settings")
    return(invisible(""))
  }

  cli_alert_success("Setup complete!")

}



get_email_setup <- function(){
  email <- usethis::ui_yeah("Do you want to setup a Cloud Scheduler email?")
  if(email){
    reuse_auth <- usethis::ui_yeah("Do you want to use the email from your JSON service account auth key?",
                                   yes = "Yes (Recommended)", no = "No")
    if(reuse_auth){
      if(Sys.getenv("GCE_AUTH_FILE") == ""){
        cli_alert_info("You need to setup the auth environment argument before configuring an email from it.  Rerun the wizard once it is setup")
        return(NULL)
      }

      the_email <- jsonlite::fromJSON(Sys.getenv("GCE_AUTH_FILE"))$client_email
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

  if(Sys.getenv("GCE_DEFAULT_PROJECT_ID") == ""){
    cli_alert_info("You need to setup the project-id environment argument before configuring a bucket.  Rerun the wizard once it is setup")
    return(NULL)
  }

  bucket <- usethis::ui_yeah("Do you want to setup a Cloud Storage bucket?")
  if(bucket){
    has_bucket <- usethis::ui_yeah("Do you have an existing Cloud Storage bucket you want to use?")
    if(has_bucket){
      cli_alert_info(paste("Fetching your buckets under the project-id: ",
                     Sys.getenv("GCE_DEFAULT_PROJECT_ID")))
      bucks <- googleCloudStorageR::gcs_list_buckets(Sys.getenv("GCE_DEFAULT_PROJECT_ID"))
      print(bucks[ , c("name", "location")])
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
          Sys.getenv("GCE_DEFAULT_PROJECT_ID"))
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

  # aborted setup auth
  if(is.null(auth)) return(NULL)

  if(auth){
    fs <- usethis::ui_yeah("Ready to browse to the file to be used for authentication?",
                     yes = "Ready", no = "Cancel")
    if(!fs) return(NULL)

    auth_file <- file.choose()
    check_file <- tryCatch(jsonlite::fromJSON(auth_file),
                           error = function(err){
                             cli_alert_danger("Could not read JSON file: {auth_file}")
                             NULL})
    if(!is.null(check_file$type) &&
       check_file$type == "service_account" &&
       !is.null(check_file$private_key)){
      cli_alert_success("Validated authentication JSON file")
      return(paste0("GCE_AUTH_FILE=", auth_file))
    }

    cli_alert_danger("Checked {auth_file} and it was not a valid JSON file? Confirm file is JSON service account auth key - see website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")

  }

  cli_ul("Run cr_setup_auth()")

  cli_ul("See website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")

  NULL

}

get_project_setup <- function(){
  project <- usethis::ui_yeah("Do you have a Google Cloud project-id to use?",
                              yes = "Yes", no = "No")
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
    return(TRUE)
  }
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
                          file = "googlecloudrunner-auth-key.json"){

  if(Sys.getenv("GAR_CLIENT_JSON") == ""){
    cli_alert_info("Could not find a OAuth 2.0 Client ID via GAR_CLIENT_JSON")

    client_id <- usethis::ui_yeah("Have you downloaded a Client ID file?",
                                  yes = "Yes", no = "No")

    if(!client_id){
      cli_alert_warning("You must have a client ID file to proceed.")
      cli_alert_info("Download via https://console.cloud.google.com/apis/credentials :")
      cli_li(c("GCP Console Sidebar Menu >",
                    "APIs & Services >",
                    "Credentials >",
                    "+ Create Credentials",
                    "OAuth client ID >",
                    "Other >",
                    "Download to your PC"))
      cli_rule()
      cli_alert_info("Rerun this wizard once you have your Client ID file")
      return(NULL)
    }

    ff <- usethis::ui_yeah("Select location of your client ID file:",
                           yes = "Ready", no = "Cancel")

    if(!ff){
      return(NULL)
    }

    json <- file.choose()
    valid <- validate_json(json)

    if(valid){
      edit_renviron(paste0("GAR_CLIENT_JSON=",json))
    }
    # we always return that cr_setup() needs to be rerun
    return(NULL)

  }

  cli_alert_info("Using Client ID via GAR_CLIENT_JSON")
  cli_rule()
  json <- Sys.getenv("GAR_CLIENT_JSON")
  if(!validate_json(json)){
    return(NULL)
  }

  create_service <- usethis::ui_yeah("Client ID present but no service authentication file is configured.  Do you want to provision a service account for your project?",
                                     yes = "Yes, I need a service account key",
                                     no = "No, I already have one downloaded")

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
    return(NULL)
  }

  cli_alert_success("Service JSON key is now created")
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
    cli::cli_alert_success("Validated Client ID file {json}")
    cli::cli_alert_success("Found Client ID project: {validated$installed$project_id}")
    return(TRUE)
  } else {
    cli::cli_alert_danger("Could not read details from client ID file - is it the right one?")
    return(FALSE)
  }

}

edit_renviron <- function(to_paste){
  session_user <- menu(title = "Do you want to configure for all R sessions or just this project?",
                       choices = c("All R sessions (Recommended)", "Project only"))
  if(session_user == 1){
    scope <- "user"
  } else if(session_user == 2){
    scope <- "project"
  } else {
    stop("User cancelled setup", call. = FALSE)
  }
  cli_ul("Include this code in your .Renviron to set for all future R sessions")
  usethis::ui_code_block(to_paste)
  usethis::edit_r_environ(scope = scope)
}

#' A helper setup function for setting up use with googleCloudRunner
#'
#'
#' @export
#' @import usethis
cr_setup <- function(){

  ui_info(c("==Welcome to googleCloudRunner setup=="))

  if(!interactive()){
    stop("Can only be used in an interactive R session", call. = FALSE)
  }

  ready <- menu(title = "This wizard will scan your system for setup options and help you setup any that are missing. \nHit 0 or ESC to cancel.",
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
    ui_todo("Include this code in your .Renviron to set for all future R sessions")
    ui_code_block(to_paste)
    edit_r_environ()
    ui_todo("Rerun cr_setup() once complete to check settings")
    return(invisible(""))
  }

  ui_done("Setup complete!")

}

get_email_setup <- function(auth_file){
  email <- ui_yeah("Do you want to setup a Cloud Scheduler email?")
  if(email){
    reuse_auth <- ui_yeah("Do you want to use the email from your JSON service account auth key?")
    if(reuse_auth){
      if(Sys.getenv("GCE_AUTH_FILE") == ""){
        ui_info("You need to setup the auth environment argument before configuring an email from it.  Rerun the wizard once it is setup")
        return(NULL)
      }

      the_email <- jsonlite::fromJSON(auth_file)$client_email
    } else {
      the_email <- readline("Enter the service email you wish to use")
    }

    ui_info("Using email: {the_email}")
    return(paste0("CR_BUILD_EMAIL=", the_email))

  }

  ui_warn("Cloud Scheduler (cr_schedule()) functionality will not be available
          unless an email is specified via cr_email_set()")

  NULL

}

get_region_setup <- function(){
  region <- ui_yeah("Do you want to setup a Cloud Run region?")
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
      ui_done(paste("Selected region:", the_region))
      return(paste0("CR_REGION=", the_region))
    } else {
      ui_warn("No region selected")
    }

  }

  ui_warn("Cloud Run (cr_run_*) functionality will not be available
          unless a region is configured via cr_region_set()")

  NULL

}

get_bucket_setup <- function(){

  if(Sys.getenv("GCE_AUTH_FILE") == ""){
    ui_info("You need to setup the auth environment argument before configuring a bucket.  Rerun the wizard once it is setup")
    return(NULL)
  }

  bucket <- ui_yeah("Do you want to setup a Cloud Storage bucket?")
  if(bucket){
    has_bucket <- ui_yeah("Do you have an existing Cloud Storage bucket you want to use?")
    if(has_bucket){
      the_bucket <- readline("What is the name of your bucket? e.g. my-bucket-name: ")
      check_bucket <- tryCatch(
        googleCloudStorageR::gcs_get_bucket(the_bucket),
        error = function(err){
          ui_stop("Could not get bucket: {err$message}")
          return(NULL)
        })
      if(!is.null(check_bucket$kind) && check_bucket$kind == "storage#bucket"){
        ui_info("Validated Cloud Storage bucket")
        return(paste0("GCS_DEFAULT_BUCKET=", the_bucket))
      } else {
        ui_stop("Invalid bucket: {the_bucket}")
        return(NULL)
      }

    } else {
      make_bucket <- ui_yeah("Do you want to make a new Cloud Storage bucket?")
      if(make_bucket){
        make_bucket_name <- readline(
    paste("What name will the bucket be? It will be created in your project: ",
          cr_project_get())
          )
        new_bucket <- googleCloudStorageR::gcs_create_bucket(
          make_bucket_name, projectId = cr_project_get()
        )
        if(!is.null(new_bucket$kind) && new_bucket$kind == "storage#bucket"){
          ui_done("Successfully created bucket {make_bucket_name}")
          return(paste0("GCS_DEFAULT_BUCKET=", new_bucket))
        }

      } else {
        ui_todo("No bucket set")
      }
    }
  }

  ui_warn("Some Cloud Build (cr_build_*) functionality will not be available
          with a bucket unless configured via cr_bucket_set()")

  NULL
}

get_auth_setup <- function(){

  auth <- ui_yeah("Have you created and downloaded a JSON service account auth key?")

  if(auth){
    ui_todo("Browse to the file to be used for authentication")
    auth_file <- file.choose()
    check_file <- tryCatch(jsonlite::fromJSON(auth_file),
                           error = function(err){
                             ui_warn("Could not read JSON file: {auth_file}")
                             NULL})
    if(!is.null(check_file$type) &&
       check_file$type == "service_account" &&
       !is.null(check_file$private_key)){
      ui_done("Validated authentication JSON file")
      return(list(env_arg = paste0("GCE_AUTH_FILE=", auth_file),
                  auth_file = auth_file))
    }

    ui_stop("Checked {auth_file} and it was not a valid JSON file? Confirm file is JSON service account auth key - see website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")

  }

  ui_todo("Create a JSON service account auth key in your GCP project")

  ui_todo("See website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")

  NULL

}

get_project_setup <- function(){
  project <- ui_yeah("Do you have a Google Cloud project-id to use?")
  if(project){
    project_id <- readline("project-id: ")
    ui_done("Selected project-id: {project_id}")
    return(paste0("GCE_DEFAULT_PROJECT_ID=",project_id))
  }

  ui_todo("Create a Google Cloud Project with billing attached and get its project-id.  Re-do this wizard when you have one or use cr_project_set()")

  ui_todo("Visit https://cloud.google.com/docs/overview to get started")

  NULL
}

do_env_check <- function(env_arg,
                         not_present,
                         ready){
  arg <- Sys.getenv(env_arg)
  if(arg == ""){
    ui_info("No environment argument detected: {env_arg}")
    return(not_present)
  } else if(ready != 1) {
    ui_info("Editing environment argument: {env_arg}={arg}")
    return(not_present)
  } else {
    ui_done("Found: {env_arg}={arg}")
  }
  NULL
}



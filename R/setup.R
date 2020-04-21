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

  ready <- ui_yeah("This wizard will scan your system for setup options
                   and help you setup any that are missing. Shall we begin?",
                   yes = "Yes", no = "Not yet")
  if(!ready){
    stopping("User cancelled setup")
  }

  project_id <- do_env_check("GCE_DEFAULT_PROJECT_ID1", get_project_setup())
  if(is.null(project_id)) return(invisible(""))

  auth_file  <- do_env_check("GCE_AUTH_FILE1", get_auth_setup())
  if(is.null(auth_file)) return(invisible(""))

  bucket     <- do_env_check("GCS_DEFAULT_BUCKET1", get_bucket_setup())
  region     <- do_env_check("CR_REGION1", get_region_setup())
  email      <- do_env_check("CR_BUILD_EMAIL1",
                             get_email_setup(auth_file$auth_file))

  to_paste <- c(project_id,
                auth_file$env_arg,
                bucket,
                region,
                email)

  if(!is.null(to_paste)){
    ui_todo("Include this code in your .Renviron to set for all future R sessions")
    ui_code_block(to_paste)
    edit_r_environ()
    stopping("Rerun cr_setup() once complete to check settings")
    return(invisible(""))
  }

  ui_done("Environment argument setup complete!")

}

get_email_setup <- function(auth_file){
  email <- ui_yeah("Do you want to setup a Cloud Scheduler email?")
  if(email){
    reuse_auth <- ui_yeah("Do you want to use the email from your JSON service account auth key?")
    if(reuse_auth){
      the_email <- jsonlite::fromJSON(auth_file)$client_email
    } else {
      the_email <- readline("Enter the service email you wish to use")
    }

    ui_info("Using email: {the_email}")
    return(paste0("CR_BUILD_EMAIL=", the_email))

  }

  ui_warn("Cloud Scheduler (cr_schedule_*) functionality will not be available
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
  bucket <- ui_yeah("Do you want to setup a Cloud Storage bucket?")
  if(bucket){
    has_bucket <- ui_yeah("Do you have an existing Cloud Storage bucket you want to use?")
    if(has_bucket){
      the_bucket <- readline("What is the name of your bucket? e.g. my-bucket-name: ")
      check_bucket <- tryCatch(
        googleCloudStorageR::gcs_get_bucket(the_bucket),
        error = function(err){
          ui_stop("Could not get bucket: {err$message}")
          stopping()
        })
      if(!is.null(check_bucket$kind) && check_bucket$kind == "storage#bucket"){
        ui_info("Validated Cloud Storage bucket")
        return(paste0("GCS_DEFAULT_BUCKET=", the_bucket))
      } else {
        stopping("Invalid bucket: {the_bucket}")
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
    check_file <- jsonlite::fromJSON(auth_file)
    if(!is.null(check_file$type) &&
       check_file$type == "service_account" &&
       !is.null(check_file$private_key)){
      ui_done("Validated authentication JSON file")
      return(list(env_arg = paste0("GCE_AUTH_FILE=", auth_file),
                  auth_file = auth_file))
    } else {
      ui_stop("Checked {auth_file} and it was not a valid JSON file? Confirm file is JSON service account auth key - see website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")
      stopping("Could not validate auth JSON file")
    }
  } else {
    ui_todo("Create a JSON service account auth key in your GCP project")
    ui_todo("See website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")
    stopping("User to create and download JSON service account auth key")
    return(NULL)
  }
}

get_project_setup <- function(){
  project <- ui_yeah("Do you have a Google Cloud project-id to use?")
  if(project){
    project_id <- readline("project-id: ")
    ui_done("Selected project-id: {project_id}")
    return(paste0("GCE_DEFAULT_PROJECT_ID=",project_id))

  } else {
    ui_todo("Create a Google Cloud Project with billing attached and get its project-id.  Re-do this wizard when you have one or use cr_project_set()")
    ui_todo("Visit https://cloud.google.com/docs/overview to get started")
    stopping("User needs to setup GCP project-id")
  }
}

stopping <- function(message = NULL){
  ui_info(message)
  return(invisible(""))
}

do_env_check <- function(env_arg,
                         not_present){
  arg <- Sys.getenv(env_arg)
  if(arg == ""){
    ui_info("No environment argument detected: {env_arg}")
    return(not_present)
  } else {
    ui_done("Found: {env_arg}={arg}")
  }
  NULL
}



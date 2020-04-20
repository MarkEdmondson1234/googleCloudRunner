#' A helper setup function for setting up use with googleCloudRunner
#'
#'
#' @export
#' @import usethis
cr_setup <- function(){

  ui_info(c("==Welcome to googleCloudRunner setup=="))
  ready <- ui_yeah("This wizard will scan your system for setup options
                   and help you setup any that are missing. Shall we begin?",
                   yes = "Yes", no = "Not yet")
  if(!ready){
    stopping("User cancelled setup")
  }

  project_id <- do_env_check("GCE_DEFAULT_PROJECT_ID", get_project_setup())
  auth_file <- do_env_check("GCE_AUTH_FILE", get_auth_setup())
  bucket <- do_env_check("GCS_DEFAULT_BUCKET", get_bucket_setup())
  region <- do_env_check("CR_REGION", get_region_setup())
  email <- do_env_check("CR_BUILD_EMAIL", get_email_setup())

  to_paste <- c(project_id,
                auth_file,
                bucket,
                region,
                email)

  if(!is.null(to_paste)){
    ui_todo("Include this code in your .Renviron to set for all future R sessions")
    ui_code_block(to_paste)
    edit_r_environ()
    stopping("Rerun cr_setup() once done to check settings")
  }

  ui_done("Environment argument setup complete!")

}

get_email_setup <- function(){
  email <- ui_yeah("Do you want to setup a Cloud Scheduler email?")
  if(email){

  } else {
    ui_warn("Cloud Scheduler (cr_schedule_*) functionality will not be available unless an email is specified via cr_email_set()")
  }
}

get_region_setup <- function(){
  region <- ui_yeah("Do you want to setup a Cloud Run region?")
  if(region){

  } else {
    ui_warn("Cloud Run (cr_run_*) functionality will not be available unless a region is selected via cr_region_set()")
  }

}

get_bucket_setup <- function(){
  bucket <- ui_yeah("Do you want to setup a Cloud Storage bucket?")
  if(bucket){

  } else {
    ui_warn("Some Cloud Build (cr_build_*) functionality will not be available unless selected via cr_bucket_set()")
  }
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
      ui_info("Validated JSON file")
      return(paste0("GCE_AUTH_FILE=", auth_file))
    } else {
      ui_stop("Checked {auth_file} and it was not a valid JSON file? Confirm file is JSON service account auth key - see website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")
      stopping("Could not validate auth JSON file")
    }
  } else {
    ui_todo("Create a JSON service account auth key in your GCP project")
    ui_todo("See website https://code.markedmondson.me/googleCloudRunner/articles/setup.html#local-auth-email")
    stopping("User to create and download JSON service account auth key")
  }
}

get_project_setup <- function(){
  project <- ui_yeah("Do you have a Google Cloud project-id to use?")
  if(project){
    project_id <- readline("project-id: ")
    return(paste0("GCE_DEFAULT_PROJECT_ID=",project_id))

  } else {
    ui_todo("Create a Google Cloud Project with billing attached and get its project-id.  Re-run this wizard when you have one or use cr_project_set()")
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



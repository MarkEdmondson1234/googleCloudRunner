#' @noRd
do_build_service_setup <- function(){

  build_email <- paste0(extract_project_number(),
                        "@cloudbuild.gserviceaccount.com")

  cli_alert_info("The Cloud Build service account ({build_email}) will need permissions during builds for certain operations calling other APIs.  This is distinct from the local authentication file you have setup.")
  do_it <- menu(title = "What services do you want to setup for the Cloud Build service account? (Esc or 0 to skip)",
                choices = c("Something not listed below",
                            "All of the below",
                            "Cloud Run deployments",
                            "Secret Manager",
                            "BigQuery operations",
                            "Cloud Storage operations"))
  if(do_it == 0){
    cli_alert_danger("Cloud Build service account will need permissions to complete certain operations.")
    return(NULL)
  }

  if(do_it == 1){
    cli_alert_danger("You will need to configure this yourself using cr_setup_service(), giving the build email {build_email} access to the role you require.")
    return(NULL)
  }

  if(do_it %in% c(2,3)){
    cli_alert_info("Configuring {build_email} for Cloud Run deployments")
    cr_setup_service(build_email, roles = cr_setup_role_lookup("cloudrun"))
  }

  if(do_it %in% c(2,4)){
    cli_alert_info("Configuring {build_email} to be able to access Secret Manager")
    cr_setup_service(build_email, roles = cr_setup_role_lookup("secrets"))
  }

  if(do_it %in% c(2,5)){
    cli_alert_info("Configuring {build_email} for BigQuery API tasks")
    cr_setup_service(build_email, roles = cr_setup_role_lookup("bigquery"))
  }

  if(do_it %in% c(2,6)){
    cli_alert_info("Configuring {build_email} for Cloud Storage API tasks")
    cr_setup_service(build_email, roles = cr_setup_role_lookup("cloudstorage"))
  }

  TRUE

}


#' @noRd
#' @return NULL if no changes, ENV_ARG="blah" if change
get_email_setup <- function(){
  email <- usethis::ui_yeah("Do you want to setup a Cloud Scheduler email?")
  if(email){
    reuse_auth <- usethis::ui_yeah("Do you want to use the email from your JSON service account auth key?",
                                   yes = "Yes (Recommended)", no = "No")
    if(reuse_auth){
      if(Sys.getenv("GCE_AUTH_FILE") == ""){
        cli_alert_info("You need to setup the auth environment argument before configuring an email from it. (If you just set it up, R needs to be restarted and the wizard rerun to see it here.)")
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

#' @noRd
#' @return NULL if no changes, ENV_ARG="blah" if change
#' @importFrom utils menu
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

#' @noRd
#' @return NULL if no changes, ENV_ARG="blah" if change
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
      googleCloudStorageR::gcs_auth(Sys.getenv("GCE_AUTH_FILE"))
      bucks <- tryCatch(googleCloudStorageR::gcs_list_buckets(Sys.getenv("GCE_DEFAULT_PROJECT_ID")),
                        error = function(err){
                          cli_alert_danger("Could not fetch a list of your buckets - {err$message}")
                          return(NULL)
                        })
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

#' @noRd
#' @return NULL if no changes, ENV_ARG="blah" if change
get_auth_setup <- function(session_user){

  auth <- cr_setup_auth(session_user = session_user)

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

  NULL

}

#' @noRd
#' @return NULL if no changes, ENV_ARG="blah" if change
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

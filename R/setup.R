#' A helper setup function for setting up use with googleCloudRunner
#'
#'
#' @export
#' @import cli googleAuthR
#' @importFrom utils menu packageVersion
#' @family setup functions
cr_setup <- function() {
  op <- gar_setup_menu(
    choices = c(
      "Configure/check all googleCloudRunner settings",
      "Configure GCP Project Id",
      "Configure Authentication JSON file",
      "Configure Cloud Run region",
      "Configure Cloud Storage bucket",
      "Configure Cloud Scheduler build email",
      "Configure Cloud Build service account"
    ),
    package_name = "googleCloudRunner"
  )

  session_user <- gar_setup_check_session()

  we_edit <- op == 2
  project_id <- gar_setup_menu_do(op,
    trigger = c(1, 2),
    do_function = gar_setup_env_check,
    stop = TRUE,
    env_arg = "GCE_DEFAULT_PROJECT_ID",
    set_to = get_project_setup(),
    edit_option = we_edit,
    session_user = session_user
  )

    if (we_edit) {
    return(invisible(""))
  }

  cli_rule()
  we_edit <- op == 3
  auth_file <- gar_setup_menu_do(op,
    trigger = c(1, 3),
    do_function = gar_setup_env_check,
    env_arg = "GCE_AUTH_FILE",
    set_to = gar_setup_get_authenv(
      session_user = session_user,
      env_arg = "GCE_AUTH_FILE",
      file = "googlecloudrunner-auth-key.json",
      client_json = "GAR_CLIENT_JSON",
      roles = cr_setup_role_lookup("local"),
      default_key = "googlecloudrunner"
    ),
    edit_option = we_edit,
    stop = TRUE,
    session_user = session_user
  )

  if (we_edit) {
    return(invisible(""))
  }

  gar_setup_auth_check("GCE_AUTH_FILE",
    scope = "https://www.googleapis.com/auth/cloud-platform"
  )

  cli_rule()
  we_edit <- op == 4
  region <- gar_setup_menu_do(op,
                              trigger = c(1, 5),
                              do_function = gar_setup_env_check,
                              env_arg = "CR_REGION",
                              set_to = get_region_setup(),
                              edit_option = we_edit,
                              session_user = session_user
  )
  if (we_edit) {
    return(invisible(""))
  }

  cli_rule()
  we_edit <- op == 5
  bucket <- gar_setup_menu_do(op,
    trigger = c(1, 4),
    do_function = gar_setup_env_check,
    env_arg = "GCS_DEFAULT_BUCKET",
    set_to = get_bucket_setup(),
    edit_option = we_edit,
    session_user = session_user
  )
  if (we_edit) {
    return(invisible(""))
  }

  cli_rule()
  we_edit <- op == 6
  email <- gar_setup_menu_do(op,
    trigger = c(1, 6),
    do_function = gar_setup_env_check,
    env_arg = "CR_BUILD_EMAIL",
    set_to = get_email_setup(),
    edit_option = we_edit,
    session_user = session_user
  )
  if (we_edit) {
    return(invisible(""))
  }
  cli_rule()
  we_edit <- op == 7
  build_service <- gar_setup_menu_do(op,
    trigger = c(1, 7),
    do_function = do_build_service_setup
  )

  if (we_edit) {
    return(invisible(""))
  }
  cli_rule()


  if (all(email, region, bucket, auth_file, project_id, build_service)) {
    cli_alert_success("Setup complete! You can test it with cr_setup_test()")
    cli_rule()
    return(invisible(""))
  }

  cli_alert_info("Some setup still to complete.
                 Restart R and/or rerun cr_setup() when ready")

  cli_rule()
}

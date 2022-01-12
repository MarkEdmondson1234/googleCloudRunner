#' Run tests over your setup
#'
#' This allows you to check if your setup works - run \link{cr_setup} first.
#' @param option Default will use an interactive menu, select other option to run that test without a menu
#' @export
#' @family setup functions
#' @examples
#' \dontrun{
#' # start the menu for interactive use
#' cr_setup_test()
#'
#' # skip menu and run all tests
#' cr_setup_test("all")
#'
#' # run just the plumber deployment test
#' cr_setup_test("plumber")
#' }
cr_setup_test <- function(option = c(
                            "menu",
                            "all",
                            "docker",
                            "plumber",
                            "r_script",
                            "r_schedule"
                          )) {
  option <- match.arg(option)

  test_results <- list()
  cli_alert_info("Perform deployments to test your setup is working. Takes around 5mins.  ESC or 0 to skip.")

  googleAuthR::gar_setup_auth_check("GCE_AUTH_FILE")

  if (option == "menu") {
    run_tests <- utils::menu(
      title = "Select which deployments to test",
      choices = c(
        "All tests",
        "Cloud Build - Docker",
        "Cloud Run - plumber API with Pub/Sub",
        "Cloud Build - R script",
        "Cloud Scheduler - R script"
      )
    )
  } else {
    run_tests <- switch(option,
      "all" = 1,
      "docker" = 2,
      "plumber" = 3,
      "r_script" = 4,
      "r_schedule" = 5
    )
  }

  if (run_tests == 0) {
    cli_alert_info("Skipping deployment tests")
  }

  runme <- system.file("example/",
    package = "googleCloudRunner",
    mustWork = TRUE
  )

  if (run_tests %in% c(1, 2)) {
    cli::cli_h2("Attempting Docker deployment on Cloud Build via cr_deploy_docker()")
    test_results <- c(test_results, setup_test_build_docker(runme))
  }

  if (run_tests %in% c(1, 3)) {
    cli::cli_h2("Attempting deployment of plumber API on Cloud Run via cr_deploy_plumber()")
    test_results <- c(test_results, setup_test_deploy_plumber(runme))
  }

  r_lines <- c(
    "list.files()",
    "library(dplyr)",
    "mtcars %>% select(mpg)",
    "sessionInfo()"
  )

  if (run_tests %in% c(1, 4)) {
    cli::cli_h2("Testing Cloud Build R scripts deployments via cr_deploy_r()")
    test_results <- c(test_results, setup_test_deploy_r(r_lines))
  }

  if (run_tests %in% c(1, 5)) {
    cli::cli_h2("Testing scheduling R script deployments via cr_deploy_r(schedule = '* * * * *')")
    test_results <- c(test_results, setup_test_schedule_r(r_lines))
  }

  cli::cli_rule()
  cli::cli_h1("Test summary")
  lapply(test_results, cli::cli_alert_info)
  cli::cli_alert_success("Deployment tests complete!")

  TRUE
}

setup_test_build_docker <- function(runme) {

  # check has access to the bucket
  tryCatch(
    googleCloudStorageR::gcs_list_objects(cr_bucket_get()),
           error = function(err) {
             stop(
               "Could not see objects in ", cr_bucket_get(),
               " - authentication JSON email needs access?
                    Rerun cr_setup() and select 'Configure Cloud Storage bucket'"
             )
           }
  )

  cd <- cr_deploy_docker(runme, launch_browser = TRUE)
  if (cd$status != "SUCCESS") {
    cli::cli_alert_danger("Something is wrong with Cloud Build setup")
    test_results <- "Something is wrong with Cloud Build setup"
  } else {
    cli::cli_alert_success("Cloud Build Docker deployment successful")
    test_results <- "Cloud Build Docker deployment successful"
  }

  test_results
}

setup_test_deploy_plumber <- function(runme){
  cr <- cr_deploy_plumber(runme,
                          dockerfile = paste0(runme, "Dockerfile")
  )
  if (is.null(cr$kind) || cr$kind != "Service") {
    cli::cli_alert_danger("Something is wrong with Cloud Run setup")
    return("Something is wrong with Cloud Run setup")
  }

  cli::cli_alert_success("Cloud Run plumber API deployment successful")
  test_results <- "Cloud Run plumber API deployment successful"
  print(cr_run_list())

  test_url <- cr$status$url
  cli_alert_info("Testing Pub/Sub API in example Cloud Run app: {test_url}")
  test_call <- cr_pubsub(paste0(test_url, "/pubsub"), "hello")

  if (test_call[[1]] != "Echo: hello") {
    cli::cli_alert_danger("Something is wrong with Pub/Sub setup")
    return(c(test_results, "Something is wrong with Pub/Sub setup"))
  }

  cli::cli_alert_success("Cloud Run plumber API Pub/Sub deployed successfully")

  c(test_results, "Cloud Run plumber API Pub/Sub deployed successfully")

}

setup_test_deploy_r <- function(r_lines){
  # check the script runs ok
  rb <- cr_deploy_r(r_lines)
  if (is.null(rb$status) || rb$status != "SUCCESS") {
    cli::cli_alert_danger("Something is wrong with Cloud Build R scripts")
    return("Something is wrong with Cloud Build R scripts")
  }

  cli::cli_alert_success("Cloud Build R scripts deployed successfully")
  "Cloud Build R scripts deployed successfully"

}

setup_test_schedule_r <- function(r_lines){
  # schedule the script
  rs <- cr_deploy_r(r_lines, schedule = "* * * * *")

  if (is.null(rs$state) || rs$state != "ENABLED") {
    cli::cli_alert_danger("Something is wrong with scheduled Cloud Build R scripts")
    return("Something is wrong with scheduled Cloud Build R scripts")
  }

  cli::cli_alert_success("Scheduled Cloud Build R scripts deployed successfully")
  cr_schedule_delete(rs)

  "Scheduled Cloud Build R scripts deployed successfully"

}

#' Run tests over your setup
#'
#' This allows you to check if your setup works - run \link{cr_setup} first.
#'
#' @export
#' @family setup functions
#' @import cli
cr_setup_test <- function(){

  test_results <- list()
  cli_alert_info("Perform deployments to test your setup is working. Takes around 5mins.  ESC or 0 to skip.")

  gar_setup_auth_check("GCE_AUTH_FILE")

  run_tests <- utils::menu(
    title = "Select which deployments to test",
    choices = c("All tests",
                "Cloud Build - Docker",
                "Cloud Run - plumber API with Pub/Sub",
                "Cloud Build - R script",
                "Cloud Scheduler - R script"
    ))

  if(run_tests == 0){
    cli_alert_info("Skipping deployment tests")
  }

  runme <- system.file("example/",
                       package="googleCloudRunner",
                       mustWork=TRUE)

  if(run_tests %in% c(1,2)){
    cli_alert_info("Attempting Docker deployment on Cloud Build via cr_deploy_docker()")

    # check has access to the bucket
    tryCatch(googleCloudStorageR::gcs_list_objects(cr_bucket_get()),
             error = function(err){
               stop("Could not see objects in ", cr_bucket_get(),
                    " - authentication JSON email needs access?
                    Rerun cr_setup() and select 'Configure Cloud Storage bucket'")
             })

    cd <- cr_deploy_docker(runme, launch_browser = TRUE)
    if(cd$status != "SUCCESS"){
      cli_alert_danger("Something is wrong with Cloud Build setup")
      test_results <- c(test_results, "Something is wrong with Cloud Build setup")
    } else {
      cli_alert_success("Cloud Build Docker deployment successful")
      test_results <- c(test_results, "Cloud Build Docker deployment successful")
    }

  }

  if(run_tests %in% c(1,3)){
    cli_alert_info("Attempting deployment of plumber API on Cloud Run via cr_deploy_plumber()")

    cr <- cr_deploy_plumber(runme,
                            dockerfile = paste0(runme, "Dockerfile"))
    if(is.null(cr$kind) || cr$kind != "Service"){
      cli_alert_danger("Something is wrong with Cloud Run setup")
      test_results <- c(test_results, "Something is wrong with Cloud Run setup")
    } else {
      cli_alert_success("Cloud Run plumber API deployment successful")
      test_results <- c(test_results, "Cloud Run plumber API deployment successful")
      print(cr_run_list())
      test_url <- cr$status$url
      cli_alert_info("Testing Pub/Sub API in example Cloud Run app: {test_url}")
      test_call <- cr_pubsub(paste0(test_url,"/pubsub"), "hello")
      if(test_call[[1]] != "Echo: hello"){
        cli_alert_danger("Something is wrong with Pub/Sub setup")
        test_results <- c(test_results, "Something is wrong with Pub/Sub setup")
      } else {
        cli_alert_success("Cloud Run plumber API Pub/Sub deployed successfully")
        test_results <- c(test_results, "Cloud Run plumber API Pub/Sub deployed successfully")
      }
    }
  }

  r_lines <- c("list.files()",
               "library(dplyr)",
               "mtcars %>% select(mpg)",
               "sessionInfo()")

  if(run_tests %in% c(1,4)){
    cli_alert_info("Testing Cloud Build R scripts deployments via cr_deploy_r()")

    # check the script runs ok
    rb <- cr_deploy_r(r_lines)
    if(is.null(rb$status) || rb$status != "SUCCESS"){
      cli_alert_danger("Something is wrong with Cloud Build R scripts")
      test_results <- c(test_results, "Something is wrong with Cloud Build R scripts")
    } else {
      cli_alert_success("Cloud Build R scripts deployed successfully")
      test_results <- c(test_results, "Cloud Build R scripts deployed successfully")
    }

  }

  if(run_tests %in% c(1,5)){
    cli_alert_info("Testing scheduling R script deployments via cr_deploy_r(schedule = '* * * * *')")

    # schedule the script
    rs <- cr_deploy_r(r_lines, schedule = "15 21 * * *")

    if(is.null(rs$state) || rs$state != "ENABLED"){
      cli_alert_danger("Something is wrong with scheduled Cloud Build R scripts")
      test_results <- c(test_results, "Something is wrong with scheduled Cloud Build R scripts")
    } else {
      cli_alert_success("Scheduled Cloud Build R scripts deployed successfully")
      test_results <- c(test_results,
                        "Scheduled Cloud Build R scripts deployed successfully")
    }
    cr_schedule_delete(rs)
  }

  cli::cli_rule()
  cli_h1("Test summary")
  lapply(test_results, cli::cli_alert_info)
  cli_alert_success("Deployment tests complete!")
}


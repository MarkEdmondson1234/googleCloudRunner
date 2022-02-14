library(testthat)
library(googleCloudRunner)

skip_if_missing_project <- function() {
  have_project <- tryCatch({
    cr_project_get()
    TRUE},
    error = function(err) FALSE)
  testthat::skip_if(!have_project, message = "No projectId set")
}

skip_if_missing_bucket <- function() {
  have_bucket <- tryCatch({
    cr_bucket_get()
    TRUE},
    error = function(err) FALSE)
  testthat::skip_if(!have_bucket, message = "No bucket set")
}

skip_if_missing_email <- function() {
  check <- tryCatch({
    cr_email_get()
    TRUE},
    error = function(err) FALSE)
  testthat::skip_if(!check, message = "No email set")
}

test_check("googleCloudRunner")

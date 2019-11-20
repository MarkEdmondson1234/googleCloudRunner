#' Launch R scripts into the Google Cloud via Cloud Build, Cloud Run and Cloud Scheduler
#'
#'
#' @docType package
#' @name googleCloudRunner
NULL


## store bucket name
.cr_env <- new.env(parent = emptyenv())

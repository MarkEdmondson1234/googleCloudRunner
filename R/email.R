#' @rdname cr_email_set
#' @export
cr_email_get <- function(){

  if(!is.null(.cr_env$cloudbuildEmail)){
    return(.cr_env$cloudbuildEmail)
  }

  if(Sys.getenv("CR_BUILD_EMAIL") != ""){
    .cr_env$cloudbuildEmail <- Sys.getenv("CR_BUILD_EMAIL")
  }
  if(is.null(.cr_env$cloudbuildEmail)){
    stop("No cloudbuildEmail set - use cr_email_set() or env arg CR_BUILD_EMAIL",
         call. = FALSE)
  }
  .cr_env$cloudbuildEmail
}

#' Get/Set cloud build email
#'
#' Needed so Cloud Scheduler can run Cloud Build jobs - can also set via environment argument CR_BUILD_EMAIL
#'
#' @seealso https://console.cloud.google.com/cloud-build/settings
#'
#' @export
#' @param cloudbuildEmail The Cloud Build service email
cr_email_set <- function(cloudbuildEmail){
  .cr_env$cloudbuildEmail <- cloudbuildEmail

  myMessage("cloudbuildEmail set to ", .cr_env$cloudbuildEmail, level = 3)
  .cr_env$cloudbuildEmail
}

#' Set the endpoint for your CloudRun services
#'
#' @param region Region for the endpoint
#' @param override Set a full endpoint starting with https here if necessary
#' @import assertthat
#' @export
cr_init <- function(region = c("europe-west1",
                               "us-central1",
                               "asia-northeast1",
                               "us-east1"),
                    override = NULL){

  region <- match.arg(region)

  if(!is.null(override)){
    .cr_env$endpoint <- override
    return(override)
  }

  .cr_env$region <- region
  .cr_env$endpoint <- sprintf("https://%s-run.googleapis.com", region)

  myMessage("Endpoint set to ", .cr_env$endpoint,
            " Region set to ", .cr_env$region, level = 3)
  .cr_env$endpoint
}
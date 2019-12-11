#' Plumber - Pub/Sub parser
#'
#' A function to use in plumber scripts to accept Pub/Sub messages
#'
#' @param message The pubsub message
#' @param pass_f An R function that will work with the data parsed out of the pubsub \code{message$data} field.
#'
#' @details
#'
#' This function is intended to be used within \link[plumber]{plumb} API scripts.  It needs to be annotated with a \code{@post} URL route and a \code{@param message The pubsub message} as per the plumber documentation.
#'
#' \code{pass_f} should be a function you create that accepts one argument, the data from the pubsub \code{message$data} field.  It is unencoded for you.
#'
#' The Docker container for the API will need to include \code{googleCloudRunner} installed in its R environment to run this function.  This is available in the public \code{gcr.io/gcer-public/cloudrunner} image.
#'
#'
#' @export
#' @examples
#'
#' \dontrun{
#'
#' # within a plumber api.R script:
#'
#' # example function echos back pubsub message
#' pub <- function(x){
#'   paste("Echo:", x)
#' }
#'
#' #' Recieve pub/sub message
#' #' @post /pubsub
#' #' @param message a pub/sub message
#' function(message=NULL){
#'   googleCloudRunner::cr_plumber_pubsub(message, pub)
#'   }
#'
#' }
#' @seealso \href{https://cloud.google.com/run/docs/tutorials/pubsub}{Google Pub/Sub tutorial for Cloud Run}
#' @family Cloud Run functions
cr_plumber_pubsub <- function(message=NULL,
                              pass_f=function(x) x){
  #
  if(is.null(message)) stop("pub/sub message not found")
  stopifnot(
    is.list(message),
    !is.null(message$data)
  )

  the_data <- rawToChar(jsonlite::base64_dec(message$data))

  pass_f(the_data)

}

#' Send a message to pubsub
#'
#' Useful for testing Cloud Run pubsub deployments
#'
#' @param payload Will be base64 encoded and placed in \code{message$data}
#' @param endpoint The url endpoint of the PubSub service
#'
#' @export
#' @importFrom httr content POST
#' @importFrom jsonlite base64_enc
cr_pubsub <- function(endpoint, payload = jsonlite::toJSON("hello")){
  content(
    POST(endpoint,
         body = list(message = list(
           data = base64_enc(payload))),
         encode="json"))
}

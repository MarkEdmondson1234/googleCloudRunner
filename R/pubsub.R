# PubSub object stuff


#' Pubsub Target Object
#'
#' @param topicName The name of the Cloud Pub/Sub topic to which messages will be published when a job is delivered.
#' @param data The message payload for PubsubMessage. An R object that will be turned into JSON via [jsonlite] and then base64 encoded into the PubSub format.
#' @param attributes Attributes for PubsubMessage.
#'
#' @return PubsubTarget object
#'
#' @family Cloud Scheduler functions
#' @export
PubsubTarget <- function(
  topicName = NULL,
  data = NULL,
  attributes = NULL
){




}

#' @export
print.ServiceList <- function(x, ...){
  print(x)
}

#' @export
print.BuildOperationMetadata <- function(x, ...){
   cat("==CloudBuildOperationMetadata==")
   cat("\nbuildId: ", x$metadata$build$id)
   cat("\nstatus: ", x$metadata$build$status)
   cat("\nlogUrl: ", x$metadata$build$logUrl)
}

#' @export
#' @importFrom yaml as.yaml
print.gar_Build <- function(x, ...){
  cat("==CloudBuildObject==")
  cat("\nbuildId: ", x$id)
  cat("\nstatus: ", x$status)
  cat("\nlogUrl: ", x$logUrl)
  cat("\nsteps: \n")
  cat(as.yaml(x$steps))
}

#' @export
print.gar_StorageSource <- function(x, ...){
  cat("==CloudBuildStorageSource==")
  cat("\nbucket: ", x$bucket)
  cat("\nobject: ", x$object)
  cat0("\ngeneration: ", x$generation)
}

#' @export
print.gar_Service <- function(x, ...){
  cat("==CloudRunService==")
  cat("\nname: ", x$metadata$name)
  cat("\nlocation: ", x$metadata$labels$`cloud.googleapis.com/location`)
  cat("\nlastModifier: ", x$metadata$annotations$`serving.knative.dev/lastModifier`)
  cat("\ncontainers: ", x$spec$template$spec$containers$image)
  cat("\ncreationTimestamp: ", x$metadata$creationTimestamp)
  cat("\nobservedGeneration: ", x$status$observedGeneration)
  cat("\nurl: ", x$status$url)
}

#' @export
print.gar_scheduleJob <- function(x, ...){
  cat("==CloudScheduleJob==")
  cat0("\nname: ", x$name)
  cat0("\nstate: ", x$state)
  cat0("\nhttpTarget.uri: ", x$httpTarget$uri)
  cat0("\nhttpTarget.httpMethod: ", x$httpTarget$httpMethod)
  cat0("\nuserUpdateTime: ", x$userUpdateTime)
  cat0("\nschedule: ", x$schedule, " ", x$timeZone)
}
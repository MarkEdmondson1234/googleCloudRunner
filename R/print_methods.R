#' @export
print.ServiceList <- function(x, ...){
  print(x)
}

#' @export
print.BuildOperationMetadata <- function(x, ...){
   cat("==CloudBuildOperationMetadata==\n")
   cat0("buildId: ", x$metadata$build$id)
   cat0("status: ", x$metadata$build$status)
   cat0("logUrl: ", x$metadata$build$logUrl)
}

#' @export
#' @importFrom yaml as.yaml
print.gar_Build <- function(x, ...){
  cat("==CloudBuildObject==\n")
  cat0("buildId: ", x$id)
  cat0("status: ", x$status)
  cat0("logUrl: ", x$logUrl)
  cat0("steps: \n")
  cat0(as.yaml(x$steps))
}

#' @export
print.gar_StorageSource <- function(x, ...){
  cat("==CloudBuildStorageSource==\n")
  cat0("bucket: ", x$bucket)
  cat0("object: ", x$object)
  cat0("generation: ", x$generation)
}

#' @export
print.gar_Service <- function(x, ...){
  cat("==CloudRunService==\n")
  cat0("name: ", x$metadata$name)
  cat0("location: ", x$metadata$labels$`cloud.googleapis.com/location`)
  cat0("lastModifier: ", x$metadata$annotations$`serving.knative.dev/lastModifier`)
  cat0("containers: ", x$spec$template$spec$containers$image)
  cat0("creationTimestamp: ", x$metadata$creationTimestamp)
  cat0("observedGeneration: ", x$status$observedGeneration)
  cat0("url: ", x$status$url)
}

#' @export
print.gar_scheduleJob <- function(x, ...){
  cat("==CloudScheduleJob==\n")
  cat0("name: ", x$name)
  cat0("state: ", x$state)
  cat0("httpTarget.uri: ", x$httpTarget$uri)
  cat0("httpTarget.httpMethod: ", x$httpTarget$httpMethod)
  cat0("userUpdateTime: ", x$userUpdateTime)
  cat0("schedule: ", x$schedule)
  cat0("timezone: ", x$timeZone)
}

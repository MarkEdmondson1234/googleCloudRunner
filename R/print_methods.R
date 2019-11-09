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
print.gar_Build <- function(x, ...){
  cat("==CloudBuildObject==")
  cat("\nbuildId: ", x$id)
  cat("\nstatus: ", x$status)
  cat("\nlogUrl: ", x$logUrl)
  cat("\nsteps: \n")
  print(x$steps)
}

#' @export
print.gar_StorageSource <- function(x, ...){
  cat("==CloudBuildStorageSource==")
  cat("\nbucket: ", x$bucket)
  cat("\nobject: ", x$object)
  cat0("\ngeneration: ", x$generation)
}
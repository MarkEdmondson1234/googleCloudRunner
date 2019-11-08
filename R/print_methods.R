#' @export
print.ServiceList <- function(x, ...){
  print(x)
}

#' @export
print.BuildOperationMetadata <- function(x, ...){
   cat("==BuildOperationMetadata==")
   cat("\nbuildId: ", x$metadata$build$id)
   cat("\nstatus: ", x$metadata$build$status)
   cat("\nlogUrl: ", x$metadata$build$logUrl)
}
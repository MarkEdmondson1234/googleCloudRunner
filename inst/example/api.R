if(Sys.getenv("PORT") == "") Sys.setenv(PORT = 8000)

#' @get /
#' @serializer html
function(){
  "<html><h1>It works!</h1></html>"
}


#' @get /hello
#' @serializer html
function(){
  "<html><h1>hello world</h1></html>"
}

#' Echo the parameter that was sent in
#' @param msg The message to echo back.
#' @get /echo
function(msg=""){
  list(msg = paste0("The message is: '", msg, "'"))
}

#' Plot out data from the iris dataset
#' @param spec If provided, filter the data to only this species (e.g. 'setosa')
#' @get /plot
#' @serializer png
function(spec){
  myData <- iris
  title <- "All Species"

  # Filter if the species was specified
  if (!missing(spec)){
    title <- paste0("Only the '", spec, "' Species")
    myData <- subset(iris, Species == spec)
  }

  plot(myData$Sepal.Length, myData$Petal.Length,
       main = title, xlab = "Sepal Length", ylab = "Petal Length")
}


#' Receive pub/sub message
#' @post /pubsub
#' @param message a pub/sub message
function(message=NULL){

  pub <- function(x) {
    paste("Echo:", x)
    }
  googleCloudRunner::cr_plumber_pubsub(message, pub)

}

#' List a Google Cloud Storage bucket as an auth example
#' @get /gcs_list
#' @param bucket the bucket to list.  Must be authenticated for this Cloud Run service account
function(bucket=NULL){
  if(is.null(bucket)){
    return("No bucket specified in URL parameter e.g ?bucket=my-bucket")
  }

  library(googleCloudStorageR)

  auth <- gargle::credentials_gce()
  if(is.null(auth)){
    return("Could not authenticate")
  }

  message("Authenticated with service token")

  # put it into googleCloudStorageR auth
  gcs_auth(token = auth)

  gcs_list_objects(bucket)

}

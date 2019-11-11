#' Set the endpoint for your CloudRun services
#'
#' Can also use environment argument CR_REGION
#'
#' @param region Region for the endpoint
#' @import assertthat
#' @export
cr_region_set <- function(region = c("europe-west1",
                                     "us-central1",
                                     "asia-northeast1",
                                     "us-east1")){

  region <- match.arg(region)

  .cr_env$region <- region

  myMessage("Region set to ", .cr_env$region, level = 3)
  .cr_env$region
}

#' Get Region Set
#' @export
cr_region_get <- function(){

  if(!is.null(.cr_env$region)){
    return(.cr_env$region)
  }

  if(Sys.getenv("CR_REGION") != ""){
    .cr_env$region <- Sys.getenv("CR_REGION")
  }
  if(is.null(.cr_env$region)){
    stop("No region set - use cr_region_set() or env arg CR_REGION",
         call. = FALSE)
  }
  .cr_env$region
}

ENDPOINTS <- c("us-central1",
               "asia-northeast1",
               "europe-west1",
               "us-east1")


#' Set the projectId for your CloudRun services
#'
#' Can also use environment argument GCE_DEFAULT_PROJECT_ID
#'
#' @param projectId The projectId
#' @import assertthat
#' @export
cr_project_set <- function(projectId){

  .cr_env$project <- projectId

  myMessage("ProjectId set to ", .cr_env$project, level = 3)
  .cr_env$project
}

#' Get ProjectId
#' @export
cr_project_get <- function(){

  if(!is.null(.cr_env$project)){
    return(.cr_env$project)
  }

  if(Sys.getenv("GCE_DEFAULT_PROJECT_ID") != ""){
    .cr_env$project <- Sys.getenv("GCE_DEFAULT_PROJECT_ID")
  }
  if(is.null(.cr_env$project)){
    stop("No projectId set - use cr_project_set() or env arg GCE_DEFAULT_PROJECT_ID",
         call. = FALSE)
  }
  .cr_env$project
}



#' Set the Cloud Storage bucket for your Cloud Build Service
#'
#' Can also use environment arg GCS_DEFAULT_BUCKET
#'
#' @param bucket The GCS bucket
#' @import assertthat
#' @export
cr_bucket_set <- function(bucket){

  .cr_env$bucket <- bucket

  myMessage("Bucket set to ", .cr_env$bucket, level = 3)
  .cr_env$bucket
}

#' Get Cloud Storage bucket
#' @export
cr_bucket_get <- function(){

  if(!is.null(.cr_env$bucket)){
    return(.cr_env$bucket)
  }

  if(Sys.getenv("GCS_DEFAULT_BUCKET") != ""){
    .cr_env$bucket <- Sys.getenv("GCS_DEFAULT_BUCKET")
  }
  if(is.null(.cr_env$bucket)){
    stop("No bucket set - use cr_bucket_set() or env arg GCS_DEFAULT_BUCKET",
         call. = FALSE)
  }
  .cr_env$bucket
}

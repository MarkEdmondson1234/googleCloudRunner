library(googleCloudStorageR)
gargle::credentials_gce()

gsuri <- '${_TARGET_BUCKET}'

objs <-tryCatch(
  gcs_list_objects(
    bucket = dirname(gsuri),
    prefix = basename(gsuri)
  ),
  error = function(err){
    message("Couldn't list files for ", gsuri)
    return(NULL)
  })

if(!is.null(objs)){
  lapply(objs[["name"]],
    function(x){
      gcs_get_object(x, bucket = dirname(gsuri), saveToDisk = x)
    })
}

TRUE

library(googleCloudStorageR)

# ridc hoops for client
client <- '${_USER_CLIENT}'
write(client, file = "client.json")
googleAuthR::gar_set_client("client.json")

gcs_auth(token=gargle::credentials_gce())
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
      target_file <- file.path("_targets","meta",basename(x))
      message("Downloading ", x, "to", target_file)
      gcs_get_object(x,
                     bucket = dirname(gsuri),
                     saveToDisk = target_file,
                     overwrite = TRUE)
    })
}

TRUE

library(googleCloudStorageR)
library(gargle)

test_f <- function(token, x){
  tryCatch({
    googleAuthR::gar_auth(token = token)
    message(paste(x, "worked"))
    googleCloudStorageR::gcs_list_buckets("mark-edmondson-gde")
  }, error = function(ex) {
    message(paste(x, "failed"))
    message("error: ", ex)
  })
}

file.exists("~/.config/gcloud/application_default_credentials.json")

test_f(credentials_app_default(
  scopes = "https://www.googleapis.com/auth/cloud-platform"),
  "credentials_app_default()")

test_f(credentials_gce(
  scopes = "https://www.googleapis.com/auth/cloud-platform"),
  "credentials_gce()")

test_f(googleAuthR::gar_gce_auth(
  "default",
  scopes = "https://www.googleapis.com/auth/cloud-platform"),
  "gar_gce_auth()")

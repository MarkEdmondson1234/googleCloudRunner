get_service_email <- function(){
    auth_json <- jsonlite::fromJSON(Sys.getenv("GCE_AUTH_FILE"))
    auth_json$client_email
}
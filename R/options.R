.onAttach <- function(libname, pkgname){

  attempt <- try(
    googleAuthR::gar_attach_auto_auth(
      "https://www.googleapis.com/auth/cloud-platform",
      environment_var = "GCE_AUTH_FILE"))
  if(inherits(attempt, "try-error")){
    warning("Tried to auto-authenticate but failed.")
  }

  invisible()

}

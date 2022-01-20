
handle_errs <- function(f,
                        http_404 = NULL,
                        http_403 = NULL,
                        return_404 = NULL,
                        return_403 = NULL,
                        projectId = cr_project_get(),
                        ...){

  tryCatch(
    f(...),
    http_404 = function(err){
      if(is.null(http_404)){
        cli::cli_alert_danger("404 Not found")
        return(NULL)
      } else {
        force(http_404)
        return(return_404)
      }

    },
    http_403 = function(err){
      if(is.null(http_403)){
        cli::cli_alert_danger("The caller does not have permission for project: {projectId}")
        return(NULL)
      } else {
        force(http_403)
        return(return_403)
      }
    }
  )

}



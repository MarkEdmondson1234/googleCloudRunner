rstudio_add_job <- function(task_name, timeout){
  if(!rstudioapi::isAvailable()) return(NULL)

  rstudioapi::jobAdd(paste0("cloudRunner - " , task_name),
                     progressUnits = as.integer(timeout),
                     running = TRUE, autoRemove = FALSE)
}

rstudio_add_state <- function(job_id, state){

  if(!rstudioapi::isAvailable()) return(NULL)
  if(is.null(job_id)) return(NULL)

  r_state <- switch(state,
      STATUS_UNKNOWN = "idle",
      QUEUED = "idle",
      WORKING = "running",
      SUCCESS = "succeeded",
      FAILURE = "failed",
      INTERNAL_ERROR = "failed",
      TIMEOUT = "failed",
      CANCELLED = "cancelled"
      )

  #rstudioapi::jobSetStatus(job_id, state)
  rstudioapi::jobSetState(job_id, r_state)
}

rstudio_add_progress <- function(job_id, add){
  if(!rstudioapi::isAvailable()){
    myMessage("\nRuntime: ",add, level = 3)
    return(NULL)
  }
  if(is.null(job_id)) return(NULL)

  rstudioapi::jobAddProgress(job_id, add)
}


rstudio_add_output <- function(job_id, text){
  if(!rstudioapi::isAvailable()){
    return(myMessage("\n",text, level = 3))
  }
  if(is.null(job_id)) return(NULL)

  rstudioapi::jobAddOutput(job_id, text)
}

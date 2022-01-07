#' Use this within your _targets functions to send the step to Cloud Build
#' @export
#' @param x A list of \link[targets]{tar_target} you want to run on Cloud Build
#' @inheritParams cr_buildstep_targets_single
cr_build_tar_target <- function(x,
                                bucket = cr_bucket_get(),
                                target_folder = NULL,
                                task_args = NULL,
                                strategy = c("single","multi"),
                                task_image = task_image){

  strategy <- match.arg(strategy)

  tmp_target <- tempfile()
  # make our own mini-target pipeline
  targets::tar_script(
    x,
    ask = FALSE,
    script = tmp_target
  )

  if(strategy == "single"){
    bs <- cr_buildstep_targets_single(
      target_folder = paste0(target_folder,basename(tmp_target)),
      bucket = bucket,
      task_image = task_image,
      task_args = task_args
    )
  } else if(strategy == "multi"){
    bs <- cr_buildstep_targets_multi(
      target_folder = paste0(target_folder,basename(tmp_target)),
      bucket = bucket,
      task_image = task_image,
      task_args = task_args
    )
  } else {
    stop("Unknown buildstep strategy", call. = FALSE)
  }

  cr_build_targets(bs, path = NULL, execute = "now")

  targets::tar_load(x)
}

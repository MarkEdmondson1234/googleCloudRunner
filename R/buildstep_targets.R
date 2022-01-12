#' Targets Cloud Build single threaded
#' @export
#' @rdname cr_build_targets
cr_buildstep_targets_single <- function(
  target_folder = NULL,
  bucket = cr_bucket_get(),
  tar_config = NULL,
  task_image = "gcr.io/gcer-public/targets",
  task_args = NULL,
  tar_make = "targets::tar_make()"
){

  if(!is.null(tar_config)){
    assert_that(is.character(tar_config))
  }

  target_bucket <- resolve_bucket_folder(target_folder, bucket)
  c(
    cr_buildstep_targets_setup(target_bucket),
    cr_buildstep_targets(task_args = task_args,
                         tar_make = c(tar_config, tar_make),
                         task_image = task_image),
    cr_buildstep_targets_teardown(target_bucket)
  )
}

#' Buildstep to run a targets pipeline on Cloud Build
#'
#' This is a buildstep to help upload a targets pipeline, see \link{cr_build_targets} for examples and suggested workflow
#' @export
#' @param task_args If not NULL, a named list of additional arguments to send to \link{cr_buildstep_r} when its executing the \link[targets]{tar_make} command (such as environment arguments or waitFor ids)
#' @param tar_make The R script that will run in the \code{tar_make()} step. Modify to include custom settings
#' @param task_image An existing Docker image that will be used to run your targets workflow after the targets meta has been downloaded from Google Cloud Storage
#' @param id The id of the buildstep.  In link{cr_buildstep_targets_multi} this is used along with \code{waitFor} to determine the order of execution
#' @family Cloud Buildsteps
cr_buildstep_targets <- function(
  task_args = NULL,
  tar_make = "targets::tar_make()",
  task_image = "gcr.io/gcer-public/targets",
  id = "target pipeline"){

  assert_that(is.character(tar_make),
              is.string(task_image))

  do.call(
    cr_buildstep_r,
    args = c(
      task_args,
      list(
        r = tar_make,
        name = task_image,
        id = id
      )
    )
  )

}

#' @export
#' @rdname cr_buildstep_targets
#' @param bucket_folder The Google Cloud Storage bucket and folder the target metadata will be saved to, e.g. \code{gs://my-bucket/my_target_project}   You can also pass in build substitution variables such as \code{"${_MY_BUCKET}"}.
cr_buildstep_targets_setup <- function(bucket_folder){
  cr_buildstep_bash(
    bash_script = paste(
      c("mkdir -p /workspace/_targets &&",
        "mkdir -p /workspace/_targets/meta &&",
        "gsutil -m cp -r",
        sprintf("%s/_targets/meta", bucket_folder),
        "/workspace/_targets",
        "|| exit 0"), collapse = " "),
    name = "gcr.io/google.com/cloudsdktool/cloud-sdk:alpine",
    entrypoint = "bash",
    escape_dollar = FALSE,
    id = "get previous _targets metadata"
  )
}

#' @export
#' @rdname cr_buildstep_targets
#' @param last_id The final buildstep that needs to complete before the upload.  If left NULL then will default to the last tar_target step.
cr_buildstep_targets_teardown <- function(bucket_folder, last_id = NULL){
  cr_buildstep_bash(
    bash_script = paste(
      c(
        "date > buildtime.txt &&",
        "gsutil cp buildtime.txt",
        sprintf("%s/_targets/buildtime.txt", bucket_folder),
        "&& gsutil -m cp -r", "/workspace/_targets", bucket_folder,
        "&& gsutil ls -r", bucket_folder
      ),
      collapse = " "),
    name = "gcr.io/google.com/cloudsdktool/cloud-sdk:alpine",
    entrypoint = "bash",
    escape_dollar = FALSE,
    id = "Upload Artifacts",
    waitFor = last_id
  )
}

#' Create a DAG for Cloud Build from the targets pipeline
#' @inheritParams cr_buildstep_targets
#' @inheritParams cr_buildstep_targets_teardown
#' @rdname cr_build_targets
#' @export
#' @param tar_config An R script that will run before \code{targets::tar_make()} in the build e.g. \code{"targets::tar_config_set(script = 'targets/_targets.R')"}
#' @importFrom cli cli cli_ul
cr_buildstep_targets_multi <- function(
  target_folder = NULL,
  bucket = cr_bucket_get(),
  tar_config = NULL,
  task_image = "gcr.io/gcer-public/targets",
  task_args = NULL,
  last_id = NULL
){

  target_bucket <- resolve_bucket_folder(target_folder, bucket)

  myMessage("Resolving targets::tar_manifest()", level = 3)

  if(nzchar(system.file(package = "visNetwork"))){
    print(targets::tar_visnetwork())
  }

  nodes <- targets::tar_manifest()
  edges <- targets::tar_network(targets_only = TRUE)$edges

  first_id <- nodes$name[[1]]

  if(!is.null(task_args) && !is.null(task_args[["waitFor"]])){
    task_args[["waitFor"]] <- NULL
    warning("waitFor task_args overwritten as needed for DAG creation")
  }

  myMessage("# Building DAG:", level = 3)
  bst <- lapply(nodes$name, function(x){
    wait_for <- edges[edges$to == x, "from"][[1]]
    if(length(wait_for) == 0){
      wait_for <- NULL
    }

    if(x == first_id){
      wait_for <- "get previous _targets metadata"
    }

    cli(cli_ul(paste0("[", paste(wait_for, collapse = ", "), "] -> [", x, "]")))

    task_args <- c(task_args, list(waitFor = wait_for))

    cr_buildstep_targets(
      task_args = task_args,
      tar_make = c(tar_config, sprintf("targets::tar_make('%s')", x)),
      task_image = task_image,
      id = x
    )
  })

  bst <- unlist(bst, recursive = FALSE)

  if(is.null(last_id)){
    last_id <- nodes$name[[nrow(nodes)]]
  }

  cli(cli_ul(paste0("[", last_id, "] -> [ Upload Artifacts ]")))

  c(
    cr_buildstep_targets_setup(target_bucket),
    bst,
    cr_buildstep_targets_teardown(target_bucket,
                                  last_id = last_id)
  )
}

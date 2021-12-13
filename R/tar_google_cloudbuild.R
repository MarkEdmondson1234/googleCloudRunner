#' @title Set up Google Cloud Build to run a targets pipeline
#' @export
#' @family scripts
#' @description Writes a Google Cloud Build workflow file so the pipeline
#'   runs on every push to GitHub, or via a PubSub trigger (that could be scheduled). Historical runs accumulate in the
#'   configured Google Cloud Storage bucket, and the latest output is downloaded before
#'   [tar_make()] so up-to-date targets do not rerun.
#' @details Steps to set up continuous deployment:
#'   0. Create a Google Cloud Project with Cloud Build activated.
#'   1. Ensure your pipeline stays within the resource limitations of
#'     Google Cloud Build, both for storage and compute.
#'     For storage, you may wish to reduce the burden with
#'     GCP-backed storage formats like `"gcp_qs"`.
#'   2. Setup Cloud Build via `googleCloudRunner::cr_setup()`.
#'   2. Call `targets::tar_renv(extras = character(0))`
#'     to expose hidden package dependencies.
#'   3. Set up `renv` for your project (with `renv::init()`
#'     or `renv::snapshot()`). Details at
#'     <https://rstudio.github.io/renv/articles/ci.html>.
#'   4. Commit the `renv.lock` file to the `main` (recommended)
#'     or `master` Git branch.
#'   5. Run `tar_google_cloudbuild()` to create the workflow file.
#'     Commit this file to `main` (recommended) or `master` in Git.
#'   6. Create a build trigger via `tar_google_trigger`.  A common trigger is a GitHub push created via `googleCloudRunner::cr_buildtrigger_repo()`.  The first event after the trigger is created will run the pipeline, subsequent runs will only recompute the outdated targets.
#'   7. Inspect the Google Cloud Storage bucket you specified for the workflow artifacts.
#' @return Nothing (invisibly). This function writes a Google Cloud Build yaml..
#' @param path Character of length 1, file path to write the Google Cloud Build yaml
#'   workflow file.
#' @param ask Logical, whether to ask before writing if the workflow file
#'   already exists. If `NULL`, defaults to `Sys.getenv("TAR_ASK")`.
#'   (Set to `"true"` or `"false"` with `Sys.setenv()`).
#'   If `ask` and the `TAR_ASK` environment variable are both
#'   indeterminate, defaults to `interactive()`.
#' @examples
#' tar_google_cloudbuild(tempfile())
#' @param target_folder Where target metadata will sit within the Google Cloud Storage bucket as a folder
#' tar_google_cloudbuild(tempfile())
#' @param bucket The Google Cloud Storage bucket the target metadata will be saved to in folder `target_folder`
tar_google_cloudbuild <- function(
  target_folder = basename(rstudioapi::getActiveProject()),
  path = "cloudbuild_targets.yaml",
  ask = NULL,
  bucket = googleCloudRunner::cr_bucket_get()
) {

  assert_that(
    is.string(path)
  )

  dir.create(dirname(path), showWarnings = FALSE)

  if(is.null(target_folder)){
    target_folder <- "targets_cloudbuild"
    myMessage("Using folder 'targets_cloudbuild' on Google Cloud Storage for targets metadata.  Avoid clashes with other projects by specifying the target_folder or using one bucket per project",
              level = 3)
  }

  target_metadata <- paste0(target_folder, "/_targets")

  bs <- c(
    cr_buildstep_r(
      readLines(system.file("r_buildsteps","gcs_download.R",
                            package = "googleCloudRunner", mustWork = TRUE)),
      name = "gcr.io/gcer-public/googleauthr-verse",
      id = "check for existing _targets metadata",
      escape_dollar = FALSE
    ),
    cr_buildstep_bash("ls -laR", id = "debug file list"),
    cr_buildstep_r("renv::restore()",
                   name = "gcr.io/gcer-public/targets",
                   id = "Restore packages"),
    cr_buildstep_r("targets::tar_make()", name = "gcr.io/gcer-public/targets",
                   id = "target pipeline")
  )

  target_bucket <- sprintf("gs://%s/%s", bucket, target_metadata)

  yaml <- cr_build_yaml(
    bs,
    substitutions = list(`_TARGET_BUCKET` = target_bucket),
    artifacts = cr_build_yaml_artifact(paste0(target_metadata, "/**"),
                                       bucket_dir = target_folder,
                                       bucket = bucket)
  )

  cr_build_write(yaml, file = path)

  myMessage("Build config file created.  Now configure a trigger via GCP WebUI or via tar_google_buildtrigger()", level = 3)

  invisible()
}

#' @rdname tar_google_cloudbuild
#' @param trigger A trigger for the build: a GitHub repo commit via \link[googleCloudRunner]{cr_buildtrigger_repo}; a PubSub trigger via \link[googleCloudRunner]{cr_buildtrigger_pubsub}; a webhook via \link[googleCloudRunner]{cr_buildtrigger_webhook}
#' @export
tar_google_trigger <- function(
  trigger,
  path = "cloudbuild_targets.yaml"
  ) {

  googleCloudRunner::cr_buildtrigger(
    path,
    name = paste0("targets-buildtrigger-",format(Sys.time(),"%Y%m%d%H%M")),
    trigger = trigger,
    trigger_tags = "targets"
  )
}

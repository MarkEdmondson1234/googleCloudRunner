test_that("targets integrations", {
  skip_on_ci()
  skip_on_cran()

  if (!require(targets)) {
    skip("library(targets) not installed")
  }

  dir.create("targets", showWarnings = FALSE)
  on.exit(unlink("targets", recursive = TRUE), add = TRUE)

  target_yaml <- cr_build_targets(
    path = NULL,
    target_folder = "cr_build_target_tests",
    tar_make = c(
      "list.files(recursive=TRUE)",
      "targets::tar_make(script = 'targets/_targets.R')"
    )
  )
  expect_snapshot(target_yaml)

  targets::tar_config_set(
    script = "targets/_targets.R"
  )

  # test file
  write.csv(mtcars, file = "targets/mtcars.csv", row.names = FALSE)

  targets::tar_script(
    list(
      targets::tar_target(file1, "targets/mtcars.csv", format = "file"),
      targets::tar_target(input1, read.csv(file1)),
      targets::tar_target(result1, sum(input1$mpg))
    ),
    ask = FALSE
  )

  targets::tar_make()

  # get local result to compare
  result <- targets::tar_read("result1")
  expect_snapshot(result)

  upload_test_files <- function() {
    cr_build_upload_gcs(
      "targets",
      remote = "cr_build_target_test_source.tar.gz",
      deploy_folder = "targets"
    )
  }

  target_source <- upload_test_files()
  expect_snapshot(target_source)

  build <- cr_build_make(target_yaml, source = target_source)
  # initial run
  bb1 <- cr_build(build, launch_browser = FALSE)
  built1 <- cr_build_wait(bb1)
  bb1logs <- cr_build_logs(built1)

  target_logs <- function(log) {
    log[which(grepl("target pipeline", log))]
  }

  logs_of_interest1 <- target_logs(bb1logs)
  expect_true(
    any(
      grepl(
        "start target file1",
        logs_of_interest1
      ))
    )

  # second run, expect it to skip target file1 as unchanged
  bb2 <- cr_build(build, launch_browser = FALSE)
  built2 <- cr_build_wait(bb2)
  bb2logs <- cr_build_logs(built2)
  logs_of_interest2 <- target_logs(bb2logs)
  expect_true(
    any(
      grepl(
        "skip target file1",
        logs_of_interest2
      ))
    )


  # make a change to the file, expect a rerun
  mtcars2 <- mtcars
  mtcars2$mpg <- mtcars$mpg * 2
  write.csv(mtcars2,
    file = "targets/mtcars.csv",
    row.names = FALSE
  )

  target_source2 <- upload_test_files()
  expect_snapshot(target_source2)
  build <- cr_build_make(target_yaml, source = target_source2)
  # same build, but source has been updated
  bb3 <- cr_build(build, launch_browser = FALSE)
  built3 <- cr_build_wait(bb3)
  bb3logs <- cr_build_logs(built3)
  logs_of_interest3 <- target_logs(bb3logs)
  expect_true(
    any(
      grepl(
        "start target file1",
        logs_of_interest3
      ))
    )

  targets::tar_config_set(
    store = "_targets_cloudbuild/cr_build_target_tests/_targets")
  artifact_download <- cr_build_targets_artifacts(built3)

  expect_true(result != targets::tar_read("result1"))

  # clean up - delete source for next test run
  googleCloudStorageR::gcs_delete_object("cr_build_target_test_source.tar.gz",
    bucket = cr_bucket_get()
  )
  deletes <- googleCloudStorageR::gcs_list_objects(
    prefix = "cr_build_target_tests",
    bucket = cr_bucket_get()
  )
  done_deeds <- lapply(deletes$name,
    googleCloudStorageR::gcs_delete_object,
    bucket = cr_bucket_get()
  )
  expect_true(all(unlist(done_deeds)))

  targets::tar_destroy(ask = FALSE)

  unlink("_targets.yaml")
  unlink("_targets_cloudbuild", recursive = TRUE)
})

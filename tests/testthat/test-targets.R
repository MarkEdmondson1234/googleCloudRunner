test_that("targets integrations", {
  skip_on_travis()
  skip_on_cran()

  if(!require(targets)){
    skip("library(targets) not installed")
  }

  target_yaml <- cr_build_targets(
    path = NULL,
    target_folder = "cr_build_target_tests",
    tar_make = "targets::tar_make(script = 'tests/targets/_targets.R')"
  )
  expect_snapshot(target_yaml)

  tar_config_set(
    script = "tests/targets/_targets.R"
  )

  write.csv(mtcars,
            file = "tests/targets/mtcars.csv",
            row.names = FALSE)

  tar_script(
    list(
      tar_target(file1, "tests/targets/mtcars.csv", format = "file"),
      tar_target(input1, read.csv(file1)),
      tar_target(result1, sum(input1$mpg))
    ),
    ask = FALSE
  )

  tar_make()

  # get local result to compare
  result <- tar_read("result1")
  expect_snapshot(result)

  target_source <- cr_build_upload_gcs(
    "tests/targets/",
    remote = "cr_build_target_test_source.tar.gz",
    deploy_folder = "tests"
  )
  expect_snapshot(target_source)

  build <- cr_build_make(target_yaml, source = target_source)
  # initial run
  bb1 <- cr_build(build)
  built1 <- cr_build_wait(bb1)
  bb1logs <- cr_build_logs(built1)


  # second run, expect it to skip stages as unchanged
  bb2 <- cr_build(build)
  built2 <- cr_build_wait(bb2)
  bb2logs <- cr_build_logs(built2)

  # make a change to the file, expect a rerun
  mtcars2 <- mtcars
  mtcars2$mpg <- mtcars$mpg * 2
  write.csv(mtcars2,
            file = "tests/targets/mtcars.csv",
            row.names = FALSE)
  target_source2 <- cr_build_upload_gcs(
    "tests/targets/",
    remote = "cr_build_target_test_source"
  )

  bb3 <- cr_build(build, source = target_source2)




})

test_that("[Online] Test Deploy R", {
  skip_on_ci()
  skip_on_cran()

  r_lines <- c(
    "list.files()",
    "library(dplyr)",
    "mtcars %>% select(mpg)",
    "sessionInfo()"
  )
  source <- cr_build_source(RepoSource("googleCloudStorageR",
    branchName = "master"
  ))

  # check the script runs ok
  rb <- cr_deploy_r(r_lines, source = source)
  expect_equal(rb$status, "SUCCESS")

  # schedule the script
  rs <- cr_deploy_r(r_lines, schedule = "15 21 * * *", source = source)
  expect_equal(rs$state, "ENABLED")

  deleteme <- cr_schedule_delete(rs)
  expect_true(deleteme)
})

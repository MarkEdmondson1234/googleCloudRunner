test_that("[Online] Test schedule jobs", {
  skip_on_ci()
  skip_on_cran()
  cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
    package = "googleCloudRunner"
  )
  build1 <- cr_build_make(cloudbuild)

  id <- "cloud-build-test1-zzzzz"
  fid <-
    "projects/mark-edmondson-gde/locations/europe-west1/jobs/cloud-build-test1-zzzzz"

  # in case a failed test run left it up
  try(cr_schedule_delete(id))

  ss <- cr_schedule_list()
  expect_s3_class(ss, "data.frame")

  s1 <- cr_schedule(
    name = id, schedule = "11 11 * * *",
    httpTarget = cr_schedule_http(build1),
    overwrite = TRUE
  )
  expect_equal(s1$name, fid)

  s2 <- cr_schedule_get(id)
  expect_equal(s1$name, s2$name)

  s3 <- cr_schedule_pause(s1)
  expect_equal(s3$state, "PAUSED")
  s4 <- cr_schedule_resume(s3)
  expect_equal(s4$state, "ENABLED")
  s5 <- cr_schedule_run(s4)
  expect_equal(s5$state, "ENABLED")
  Sys.sleep(10) # pause to allow time for schedule list to update
  new_list <- cr_schedule_list()
  expect_true(s4$name %in% new_list$name)
  s6 <- cr_schedule(name = id, description = "edited", overwrite = TRUE)
  expect_equal(s6$description, "edited")
  deleteme <- cr_schedule_delete(id)
  expect_true(deleteme)
  Sys.sleep(10) # pause to allow time for schedule list to update
  newer_list <- cr_schedule_list()
  expect_true(!s4$name %in% newer_list$name)
})

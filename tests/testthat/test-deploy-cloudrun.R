test_that("[Online] Test Cloud Run", {
  skip_on_ci()
  skip_on_cran()

  runme <- system.file("example/",
    package = "googleCloudRunner",
    mustWork = TRUE
  )

  cr <- cr_deploy_plumber(runme,
    dockerfile = paste0(runme, "Dockerfile")
  )

  expect_equal(cr$kind, "Service")
  expect_true(grepl(
    "^gcr.io/.+/example:.+",
    cr$spec$template$spec$containers$image
  ))

  runs <- cr_run_list()
  expect_s3_class(runs, "data.frame")

  # test pubsub works for example cloud run R app
  test_url <- cr$status$url
  print(test_url)
  test_call <- cr_pubsub(paste0(cr$status$url, "/pubsub"), "hello")
  expect_equal(test_call[[1]], "Echo: hello")
})

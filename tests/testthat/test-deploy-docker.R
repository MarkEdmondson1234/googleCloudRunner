test_that("[Online] Test Docker", {
  skip_on_ci()
  skip_on_cran()

  runme <- system.file("example/",
    package = "googleCloudRunner",
    mustWork = TRUE
  )

  cd <- cr_deploy_docker(runme, kaniko_cache = FALSE)
  expect_equal(cd$status, "SUCCESS")

  # test kaniko_cache
  ccd <- cr_deploy_docker(runme, kaniko_cache = TRUE)
  expect_equal(ccd$status, "SUCCESS")
})

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


test_that("[Online] Test Docker pre_steps", {
  skip_on_ci()
  skip_on_cran()

  runme <- system.file("example/",
                       package = "googleCloudRunner",
                       mustWork = TRUE
  )

  res <- cr_buildstep_bash("echo hello")
  post_steps <- pre_steps <- res[[1]]

  expect_error({
    cr_deploy_docker(runme, kaniko_cache = FALSE,
                         pre_steps = pre_steps)
  }, regexp = "not a cr_buildstep_list")

  expect_error({
    cr_deploy_docker(runme, kaniko_cache = FALSE,
                     post_steps = post_steps)
  }, regexp = "not a cr_buildstep_list")
})

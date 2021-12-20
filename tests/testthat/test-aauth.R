test_that("Authentication and setup", {
  skip_on_ci()
  skip_on_cran()

  expect_true(nzchar(Sys.getenv("GCE_AUTH_FILE")))
  expect_true(nzchar(Sys.getenv("CR_REGION")))
  expect_true(nzchar(Sys.getenv("CR_BUILD_EMAIL")))
  expect_true(nzchar(Sys.getenv("GCS_DEFAULT_BUCKET")))
  expect_true(nzchar(Sys.getenv("GCE_DEFAULT_PROJECT_ID")))

  expect_true(
    inherits(googleAuthR::gar_token()$auth_token, "TokenServiceAccount")
  )
})

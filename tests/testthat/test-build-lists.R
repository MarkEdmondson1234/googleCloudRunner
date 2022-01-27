test_that("Build Listings and Filters", {
  skip_on_ci()
  skip_on_cran()

  # builds for this package's buildtrigger
  gcr_trigger_id <- "0a3cade0-425f-4adc-b86b-14cde51af674"
  gcr_bt <- cr_build_list_filter(
    "trigger_id",
    value = gcr_trigger_id
  )
  expect_snapshot(gcr_bt)

  gcr_builds <- cr_build_list(gcr_bt)
  expect_s3_class(gcr_builds, "data.frame")

  # get logs for last build
  last_build <- gcr_builds[1, ]
  last_build_logs <- cr_build_logs(log_url = last_build$bucketLogUrl)
  expect_true(is.character(last_build_logs))

  expect_error(cr_build_list_filter("blah", "=", "boo"))

  date_filter <- cr_build_list_filter(
    "create_time",
    ">",
    as.Date("2020-01-06") - 5
  )
  expect_snapshot(date_filter)
})

test_that("Build logs work", {
  skip_on_ci()
  skip_on_cran()

  last_logs <- cr_buildtrigger_logs("package-checks")
  expect_true(is.character(last_logs))
})

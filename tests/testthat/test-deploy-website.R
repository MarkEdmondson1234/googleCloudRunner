test_that("[Online] Test Deploy Website", {
  skip_on_ci()
  skip_on_cran()

  # deploy a website using package's NEWS.md
  dir.create("test_website", showWarnings = FALSE)

  knitr::knit2html(system.file("NEWS.md", package = "googleCloudRunner"),
    output = "test_website/NEWS.html"
  )
  # from https://testthat.r-lib.org/articles/test-fixtures.html
  # could use withr::defer, but don't need it here
  unlink("NEWS.txt")

  ws <- cr_deploy_html("test_website")
  unlink("test_website", recursive = TRUE)
  unlink("test_website.tar.gz")

  expect_equal(ws$kind, "Service")
  expect_equal(ws$metadata$name, "test-website")
  expect_equal(httr::GET(ws$status$url)$status_code, 200)
  expect_equal(httr::GET(paste0(ws$status$url, "/blah"))$status_code, 404)
  expect_equal(httr::GET(paste0(ws$status$url, "/NEWS.html"))$status_code, 200)
})

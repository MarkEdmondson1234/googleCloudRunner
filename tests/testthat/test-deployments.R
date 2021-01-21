test_that("[Online] Test deployments", {
  skip_on_travis()
  skip_on_cran()

  runme <- system.file("example/",
                       package="googleCloudRunner",
                       mustWork=TRUE)

  cd <- cr_deploy_docker(runme, launch_browser = FALSE)
  expect_equal(cd$status,"SUCCESS")

  cr <- cr_deploy_plumber(runme,
                          dockerfile = paste0(runme, "Dockerfile"))

  expect_equal(cr$kind, "Service")
  expect_true(grepl("^gcr.io/.+/example:.+",
                    cr$spec$template$spec$containers$image))

  runs <- cr_run_list()
  expect_s3_class(runs, "data.frame")

  # test pubsub works for example cloud run R app
  test_url <- cr$status$url
  print(test_url)
  test_call <- cr_pubsub(paste0(cr$status$url,"/pubsub"), "hello")
  expect_equal(test_call[[1]], "Echo: hello")

  ss <- cr_schedule_list()
  expect_s3_class(ss, "data.frame")

  r_lines <- c("list.files()",
               "library(dplyr)",
               "mtcars %>% select(mpg)",
               "sessionInfo()")
  source <- cr_build_source(RepoSource("googleCloudStorageR",
                                       branchName = "master"))

  # check the script runs ok
  rb <- cr_deploy_r(r_lines, source = source)
  expect_equal(rb$status, "SUCCESS")

  # schedule the script
  rs <- cr_deploy_r(r_lines, schedule = "15 21 * * *", source = source)
  expect_equal(rs$state, "ENABLED")

  deleteme <- cr_schedule_delete(rs)
  expect_true(deleteme)

  # deploy a website using package's NEWS.md
  dir.create("test_website")
  knitr::knit2html(system.file("NEWS.md",package="googleCloudRunner"),
                   output = "test_website/NEWS.html")
  ws <- cr_deploy_html("test_website")
  expect_equal(ws$kind, "Service")
  expect_equal(ws$metadata$name, "test-website")
  expect_equal(httr::GET(ws$status$url)$status_code, 200)
  expect_equal(httr::GET(paste0(ws$status$url,"/blah"))$status_code, 404)
  expect_equal(httr::GET(paste0(ws$status$url,"/NEWS.html"))$status_code, 200)

  # test kaniko_cache
  ccd <- cr_deploy_docker(system.file("example/", package="googleCloudRunner"),
                          kaniko_cache = 6L)
  expect_equal(ccd$status,"SUCCESS")


})

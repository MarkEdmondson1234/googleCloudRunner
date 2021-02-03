test_that("Online auth", {
  skip_on_travis()
  skip_on_cran()
  # assumes auth and necessary args taken from env args already set
  builds <- cr_buildtrigger_list()
  expect_s3_class(builds, "data.frame")

  # tests auth on cloud build
  cr_deploy_r(system.file("schedule/test_auth.R", package = "googleCloudRunner"),
              r_image = "gcr.io/gcer-public/googleauthr-verse")

})

test_that("[Online] Test building from build object", {
  skip_on_travis()
  skip_on_cran()
  cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
                            package = "googleCloudRunner")
  built <- cr_build(cloudbuild)
  sched_built <- cr_schedule("test1","* * * * *",
                             httpTarget = cr_build_schedule_http(built) )
  expect_equal(sched_built$state, "ENABLED")
  sched_list <- cr_schedule_list()
  test_name <- sprintf("projects/%s/locations/%s/jobs/test1",
                       cr_project_get(), cr_region_get())
  expect_true(test_name %in% sched_list$name)
  cr_schedule_delete("test1")

})

test_that("[Online] Test Source Repo functions", {
  skip_on_travis()
  skip_on_cran()

  sr <- cr_sourcerepo_list()

  expect_s3_class(sr, "data.frame")
})

test_that("[Online] Test build artifacts", {
  skip_on_travis()
  skip_on_cran()
  r <- "write.csv(mtcars,file = 'artifact.csv')"
  ba <- cr_build_yaml(
    steps = cr_buildstep_r(r),
    artifacts = cr_build_yaml_artifact('artifact.csv')
    )

  build <- cr_build(ba)
  built <- cr_build_wait(build)

  b <- cr_build_artifacts(built)
  expect_equal(b, "artifact.csv")
  expect_true(file.exists("artifact.csv"))
  df <- read.csv("artifact.csv")
  expect_s3_class(df, "data.frame")

  unlink("artifact.csv")

})

test_that("[Online] JWT fetches", {

  cr <- cr_run_get("parallel-cloudrun")

  # Interact with the authenticated Cloud Run service
  the_url <- cr$status$url
  jwt <- cr_jwt_create(the_url)

  # needs to be recreated every 60mins
  token <- cr_jwt_token(jwt, the_url)

  # call Cloud Run with token
  res <- cr_jwt_with_httr(
    httr::GET("https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=North%20America&industry=Transportation%20(non-freight)"),
                     token)
  o <- httr::content(res)

  expect_true(inherits(o, "list"))

  all_urls <- c("https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=North%20America&industry=Transportation%20(non-freight)"
  ,"https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=Europe&industry=Transportation%20(non-freight)"
  ,"https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=South%20America&industry=Transportation%20(non-freight)"
  ,"https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=Australia&industry=Transportation%20(non-freight)"
  ,"https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=North%20America&industry=Software")

  res2 <- cr_jwt_async(all_urls, token = token)
  expect_true(inherits(res2, "list"))
  # response is json starting with {"params" ...}
  expect_true(grepl('^\\{\\"params\\"',res2[[1]]))

})

test_that("availableSecrets works ok", {

  s1 <- cr_build_yaml_secrets("SECRET","test_secret")
  s2 <- cr_build_yaml_secrets("SECRET2","test_secret_two")

  s_yaml <- cr_build_yaml(
    steps = cr_buildstep_bash("echo $$SECRET $$SECRET2",
                              secretEnv = c("SECRET","SECRET2")),
    availableSecrets = list(s1, s2)
  )
  expect_snapshot(s_yaml)

  build <- cr_build_make(s_yaml)
  built <- cr_build(build)

  # how to test it did the right secrets in the build?

})

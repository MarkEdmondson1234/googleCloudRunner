test_that("Online auth", {
  skip_on_ci()
  skip_on_cran()
  # assumes auth and necessary args taken from env args already set
  builds <- cr_buildtrigger_list()
  expect_s3_class(builds, "data.frame")

  # tests auth on cloud build
  gg <- cr_deploy_r(
    system.file("schedule/test_auth.R", package = "googleCloudRunner"),
    r_image = "gcr.io/gcer-public/googleauthr-verse"
  )
})

test_that("[Online] Test building from build object", {
  skip_on_ci()
  skip_on_cran()
  cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
    package = "googleCloudRunner"
  )
  built <- cr_build(cloudbuild)

  cr_schedule_delete("test1")

  sched_built <- cr_schedule("test1", "* * * * *",
    httpTarget = cr_schedule_http(built)
  )
  expect_equal(sched_built$state, "ENABLED")
  sched_list <- cr_schedule_list()
  test_name <- sprintf(
    "projects/%s/locations/%s/jobs/test1",
    cr_project_get(), cr_region_get()
  )
  expect_true(test_name %in% sched_list$name)
  cr_schedule_delete("test1")
})

test_that("[Online] Test Source Repo functions", {
  skip_on_ci()
  skip_on_cran()

  sr <- cr_sourcerepo_list()

  expect_s3_class(sr, "data.frame")
})

test_that("[Online] Test build artifacts", {
  skip_on_ci()
  skip_on_cran()
  r <- "write.csv(mtcars,file = 'artifact.csv')"
  ba <- cr_build_yaml(
    steps = cr_buildstep_r(r),
    artifacts = cr_build_yaml_artifact("artifact.csv")
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


test_that("availableSecrets works ok", {
  skip_on_ci()
  skip_on_cran()

  s1 <- cr_build_yaml_secrets("SECRET", "test_secret")
  s2 <- cr_build_yaml_secrets("SECRET2", "test_secret_two")

  s_yaml <- cr_build_yaml(
    steps = cr_buildstep_bash("echo $SECRET $SECRET2",
      secretEnv = c("SECRET", "SECRET2")
    ),
    availableSecrets = list(s1, s2),
    logsBucket = paste0("gs://", cr_bucket_get())
  )
  expect_snapshot(s_yaml)

  build <- cr_build_make(s_yaml)
  built <- cr_build(build)

  the_build <- cr_build_wait(built)

  parsed_logs <- cr_build_logs(the_build)

  expect_true(any(grepl("A_SECRET_VALUE SECOND_SECRET", parsed_logs)))
})

test_that("Build status NULLs", {
  skip_on_ci()
  skip_on_cran()

  no_build <- cr_build_status("not_exist")
  expect_null(no_build)

  no_buildtrigger <- cr_buildtrigger_get("not_exist2")
  expect_null(no_buildtrigger)

})



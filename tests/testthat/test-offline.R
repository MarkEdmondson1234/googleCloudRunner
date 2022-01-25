test_that("Building Build Objects", {
  yaml <- system.file("cloudbuild/cloudbuild.yaml", package = "googleCloudRunner")

  expect_equal(basename(yaml), "cloudbuild.yaml")

  my_gcs_source <- Source(storageSource = StorageSource(
    object = "my_code.tar.gz",
    bucket = "gs://my-bucket"
  ))
  expect_true(is.gar_Source(my_gcs_source))
  expect_snapshot(my_gcs_source)

  my_repo_source <- Source(repoSource = RepoSource("https://my-repo.com",
    branchName = "master"
  ))
  expect_true(is.gar_Source(my_repo_source))
  expect_snapshot(my_repo_source)

  bq <- cr_build_make(
    yaml = yaml,
    source = my_gcs_source,
    timeout = 10,
    images = "gcr.io/my-project/demo"
  )
  expect_true(is.gar_Build(bq))
  expect_snapshot(bq)

  bq2 <- cr_build_make(
    yaml = yaml,
    source = my_repo_source,
    timeout = "11s",
    images = "gcr.io/my-project/demo"
  )
  expect_true(is.gar_Build(bq2))
  expect_snapshot(bq2)

  # write from creating a Yaml object
  image <- "gcr.io/my-project/my-image"
  run_yaml <- cr_build_yaml(
    steps = c(
      cr_buildstep_docker(image, dir = "deploy"),
      cr_buildstep("gcloud",
        c(
          "beta", "run", "deploy", "test1",
          "--image", image
        ),
        dir = "deploy"
      )
    ),
    images = image
  )

  expect_snapshot(run_yaml)

  scheduler <- cr_schedule_http(cr_build_make(run_yaml))
  expect_snapshot(scheduler$body)

  cr_build_write(run_yaml, file = "cloudbuild_test.yaml")
  expect_true(file.exists("cloudbuild_test.yaml"))

  read_b <- cr_build_make("cloudbuild_test.yaml")
  expect_snapshot(read_b)

  # write from a Build object
  build3 <- cr_build_make(system.file("cloudbuild/cloudbuild.yaml",
    package = "googleCloudRunner"
  ))
  expect_snapshot(build3)

  cr_build_write(build3, file = "cloudbuild_test2.yaml")
  expect_true(file.exists("cloudbuild_test2.yaml"))

  read_b2 <- cr_build_make("cloudbuild_test2.yaml")
  expect_snapshot(read_b2)

  unlink("cloudbuild_test.yaml")
  unlink("cloudbuild_test2.yaml")

  op <- cr_project_get()
  ob <- cr_bucket_get()
  or <- cr_region_get()
  oe <- cr_email_get()

  expect_equal(cr_project_set(op), op)
  expect_equal(cr_bucket_set(ob), ob)
  expect_equal(cr_region_set(or), or)
  expect_equal(cr_email_set(oe), oe)

  eemail <- cr_run_email("mmmmark")
  expect_snapshot(eemail)

  run_target <- cr_run_schedule_http("https://a-url.com", "mmmark")
  expect_snapshot(run_target)

  # library(googlePubsubR) #nolint
  # msg_encode(jsonlite::toJSON(list(a="hello mum"))) #nolint
  pubsub_message <- cr_plumber_pubsub(list(data = "eyJhIjpbImhlbGxvIG11bSJdfQ=="))
  expect_snapshot(pubsub_message)
})

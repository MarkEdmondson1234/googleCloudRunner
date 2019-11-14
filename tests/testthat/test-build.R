context("Offline tests")

test_that("Building Build Objects", {

  yaml <- system.file("cloudbuild/cloudbuild.yaml", package = "cloudRunner")

  expect_equal(basename(yaml), "cloudbuild.yaml" )

  my_gcs_source <- Source(storageSource=StorageSource(object = "my_code.tar.gz",
                                                      bucket = "gs://my-bucket"
                                                      ))
  expect_true(cloudRunner:::is.gar_Source(my_gcs_source))
  expect_equal(my_gcs_source$storageSource$bucket, "gs://my-bucket")

  my_repo_source <- Source(repoSource=RepoSource("https://my-repo.com",
                                                 branchName="master"))
  expect_true(cloudRunner:::is.gar_Source(my_repo_source))
  expect_equal(my_repo_source$repoSource$branchName, "master")

  bq <- cr_build_make(yaml = yaml,
                source = my_gcs_source,
                timeout = 10,
                images = "gcr.io/my-project/demo",
                projectId = "dummy-project")
  expect_true(cloudRunner:::is.gar_Build(bq))
  expect_equal(bq$images, "gcr.io/my-project/demo")
  expect_equal(bq$timeout, 10)
  expect_equal(bq$steps[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(bq$steps[[2]]$name, "alpine")
  expect_equal(bq$source$storageSource$bucket, "gs://my-bucket")

  bq2 <- cr_build_make(yaml = yaml,
                      source = my_repo_source,
                      timeout = 11,
                      images = "gcr.io/my-project/demo",
                      projectId = "dummy-project")
  expect_true(cloudRunner:::is.gar_Build(bq2))
  expect_equal(bq2$images, "gcr.io/my-project/demo")
  expect_equal(bq2$timeout, 11)
  expect_equal(bq2$steps[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(bq2$steps[[2]]$name, "alpine")
  expect_equal(bq2$source$repoSource$branchName, "master")

  # write from creating a Yaml object
  image = "gcr.io/my-project/my-image$BUILD_ID"
  run_yaml <- Yaml(steps = c(cr_buildstep_docker(image),
                             cr_buildstep("gcloud",
                                          c("beta","run","deploy", "test1",
                                            "--image", image))),
     images = image)

  expect_equal(run_yaml$images, image)
  expect_equal(run_yaml$steps[[1]]$dir, "deploy")
  expect_equal(run_yaml$steps[[2]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(run_yaml$steps[[3]]$args[[1]], "beta")

  cr_build_write(run_yaml, file = "cloudbuild_test.yaml")
  expect_true(file.exists("cloudbuild_test.yaml"))

  read_b <- cr_build_make("cloudbuild_test.yaml")
  expect_equal(read_b$steps[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(read_b$steps[[2]]$args[[1]], "push")

  # write from a Build object
  build3 <- cr_build_make(system.file("cloudbuild/cloudbuild.yaml",
                                      package = "cloudRunner"))
  expect_equal(build3$steps[[1]]$args, "version")
  expect_equal(build3$steps[[2]]$name, "alpine")

  cr_build_write(build3, file = "cloudbuild_test2.yaml")
  expect_true(file.exists("cloudbuild_test2.yaml"))

  read_b2 <- cr_build_make("cloudbuild_test2.yaml")
  expect_equal(read_b2$steps[[1]]$id, "Docker Version")
  expect_equal(read_b2$steps[[2]]$args[[1]], "echo")

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

  cloudbuild_dc <- cr_buildstep_decrypt("secret.json.enc",
                                        plain = "secret.json",
                                        keyring = "my_keyring",
                                        key = "my_key")
  expect_equal(cloudbuild_dc[[1]]$args[[1]], "kms")
  expect_equal(cloudbuild_dc[[1]]$args[[3]], "--ciphertext-file")

})



context("Online tests")

#' b2 <- cr_build_wait(b1)
#' cr_build_status(b1)
#' cr_build_status(b2)
#'   build1 <- cr_build(yaml, source = my_gcs_source)
#'   build2 <- cr_build(yaml, source = my_repo_source)
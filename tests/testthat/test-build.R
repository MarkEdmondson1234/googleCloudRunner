context("Offline tests")

context("Online tests")

test_that("Online auth", {
  skip_on_travis()

  # assumes auth and necessary args taken from env args already set
  builds <- cr_buildtrigger_list()
  expect_s3_class(builds, "data.frame")

})
#' b2 <- cr_build_wait(b1)
#' cr_build_status(b1)
#' cr_build_status(b2)
#'   build1 <- cr_build(yaml, source = my_gcs_source)
#'   build2 <- cr_build(yaml, source = my_repo_source)
#'
#'   cloudbuild <- system.file("cloudbuild/cloudbuild.yaml", package = "googleCloudRunner")
#'   bb<- cr_build_make(cloudbuild, projectId = "test-project")

test_that("Building Build Objects", {

  cr_email_set("test@cloudbuilder.com")
  cr_region_set("europe-west1")
  cr_project_set("test-project")
  cr_bucket_set("test-bucket")

  yaml <- system.file("cloudbuild/cloudbuild.yaml", package = "googleCloudRunner")

  expect_equal(basename(yaml), "cloudbuild.yaml" )

  my_gcs_source <- Source(storageSource=StorageSource(object = "my_code.tar.gz",
                                                      bucket = "gs://my-bucket"
                                                      ))
  expect_true(googleCloudRunner:::is.gar_Source(my_gcs_source))
  expect_equal(my_gcs_source$storageSource$bucket, "gs://my-bucket")

  my_repo_source <- Source(repoSource=RepoSource("https://my-repo.com",
                                                 branchName="master"))
  expect_true(googleCloudRunner:::is.gar_Source(my_repo_source))
  expect_equal(my_repo_source$repoSource$branchName, "master")

  bq <- cr_build_make(yaml = yaml,
                source = my_gcs_source,
                timeout = 10,
                images = "gcr.io/my-project/demo",
                projectId = "dummy-project")
  expect_true(googleCloudRunner:::is.gar_Build(bq))
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
  expect_true(googleCloudRunner:::is.gar_Build(bq2))
  expect_equal(bq2$images, "gcr.io/my-project/demo")
  expect_equal(bq2$timeout, 11)
  expect_equal(bq2$steps[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(bq2$steps[[2]]$name, "alpine")
  expect_equal(bq2$source$repoSource$branchName, "master")

  # write from creating a Yaml object
  image = "gcr.io/my-project/my-image"
  run_yaml <- Yaml(steps = c(cr_buildstep_docker(image, dir = "deploy"),
                             cr_buildstep("gcloud",
                                          c("beta","run","deploy", "test1",
                                            "--image", image), dir="deploy")),
     images = image)

  expect_equal(run_yaml$images, image)
  expect_equal(run_yaml$steps[[1]]$dir, "deploy")
  expect_equal(run_yaml$steps[[1]]$args[[3]],
               "gcr.io/my-project/my-image:$BUILD_ID")
  expect_equal(run_yaml$steps[[2]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(run_yaml$steps[[2]]$args[[2]],
               "gcr.io/my-project/my-image:$BUILD_ID")
  expect_equal(run_yaml$steps[[3]]$args[[1]], "beta")

  scheduler <- cr_build_schedule_http(cr_build_make(run_yaml))

  expect_equal(scheduler$body, "eyJzdGVwcyI6W3sibmFtZSI6Imdjci5pby9jbG91ZC1idWlsZGVycy9kb2NrZXIiLCJhcmdzIjpbImJ1aWxkIiwiLXQiLCJnY3IuaW8vbXktcHJvamVjdC9teS1pbWFnZTokQlVJTERfSUQiLCIuIl0sImRpciI6ImRlcGxveSJ9LHsibmFtZSI6Imdjci5pby9jbG91ZC1idWlsZGVycy9kb2NrZXIiLCJhcmdzIjpbInB1c2giLCJnY3IuaW8vbXktcHJvamVjdC9teS1pbWFnZTokQlVJTERfSUQiXSwiZGlyIjoiZGVwbG95In0seyJuYW1lIjoiZ2NyLmlvL2Nsb3VkLWJ1aWxkZXJzL2djbG91ZCIsImFyZ3MiOlsiYmV0YSIsInJ1biIsImRlcGxveSIsInRlc3QxIiwiLS1pbWFnZSIsImdjci5pby9teS1wcm9qZWN0L215LWltYWdlIl0sImRpciI6ImRlcGxveSJ9XSwiaW1hZ2VzIjoiZ2NyLmlvL215LXByb2plY3QvbXktaW1hZ2UifQ==")

  cr_build_write(run_yaml, file = "cloudbuild_test.yaml")
  expect_true(file.exists("cloudbuild_test.yaml"))

  read_b <- cr_build_make("cloudbuild_test.yaml")
  expect_equal(read_b$steps[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(read_b$steps[[2]]$args[[1]], "push")

  # write from a Build object
  build3 <- cr_build_make(system.file("cloudbuild/cloudbuild.yaml",
                                      package = "googleCloudRunner"))
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


})

context("Build steps")

test_that("Render BuildStep objects", {

  bs1 <- cr_buildstep("alpine", c("-c","ls -la"), entrypoint = "bash", prefix="")
  expect_equal(bs1[[1]]$name, "alpine")

  cloudbuild_dc <- cr_buildstep_decrypt("secret.json.enc",
                                        plain = "secret.json",
                                        keyring = "my_keyring",
                                        key = "my_key")
  expect_equal(cloudbuild_dc[[1]]$args[[1]], "kms")
  expect_equal(cloudbuild_dc[[1]]$args[[3]], "--ciphertext-file")

  bsd <- cr_buildstep_docker("my-image", tag = "$BRANCH_NAME")
  expect_equal(bsd[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(bsd[[1]]$args[[3]], "gcr.io/test-project/my-image:$BRANCH_NAME")
  expect_equal(bsd[[2]]$name,  "gcr.io/cloud-builders/docker")
  expect_equal(bsd[[2]]$args[[1]], "push")

  y <- data.frame(name = c("docker", "alpine"),
                  args = I(list(c("version"), c("echo", "Hello Cloud Build"))),
                  id = c("Docker Version", "Hello Cloud Build"),
                  prefix = c(NA, ""),
                  stringsAsFactors = FALSE)
  bsy <- cr_buildstep_df(y)
  expect_equal(bsy[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(bsy[[1]]$args, "version")
  expect_equal(bsy[[2]]$name, "alpine")
  expect_equal(bsy[[2]]$args[[1]], "echo")
  expect_equal(bsy[[2]]$id, "Hello Cloud Build")

  package_build <- system.file("cloudbuild/cloudbuild_packages.yml",
                               package = "googleCloudRunner")
  bp <- cr_build_make(package_build)
  bp1 <- cr_buildstep_extract(bp, step = 2)
  bp2 <- cr_buildstep_extract(bp, step = 3)
  expect_equal(bp1[[1]]$id, "Devtools checks")
  expect_equal(bp2[[1]]$id, "Good Practices")

  edit1 <- cr_buildstep_edit(bp2, name = "blah")
  edit2 <- cr_buildstep_edit(bp2, args = "blah")
  edit3 <- cr_buildstep_edit(bp2, name = "gcr.io/blah")
  edit4 <- cr_buildstep_edit(bp2, dir = "blah")

  expect_equal(edit1[[1]]$name, "gcr.io/cloud-builders/blah")
  expect_equal(edit2[[1]]$args, "blah")
  expect_equal(edit3[[1]]$name, "gcr.io/blah")
  expect_equal(edit4[[1]]$dir, "blah")

  git_yaml <- Yaml(
    steps = c(
      cr_buildstep_gitsetup("my_keyring", "git_key"),
      cr_buildstep_git(c("clone", "git@github.com:github_name/repo_name"))
    )
  )

  expect_equal(git_yaml$steps[[1]]$name, "gcr.io/cloud-builders/gcloud")
  expect_equal(git_yaml$steps[[1]]$args[[1]], "kms")
  expect_equal(git_yaml$steps[[1]]$args[[4]], "id_rsa.enc")
  expect_equal(git_yaml$steps[[1]]$args[[10]], "my_keyring")
  expect_equal(git_yaml$steps[[1]]$volumes[[1]]$name, "ssh")
  expect_equal(git_yaml$steps[[1]]$volumes[[1]]$path, "/root/.ssh")

  expect_equal(git_yaml$steps[[2]]$name, "gcr.io/cloud-builders/git")
  expect_equal(git_yaml$steps[[2]]$volumes[[1]]$name, "ssh")
  expect_equal(git_yaml$steps[[2]]$volumes[[1]]$path, "/root/.ssh")

  pkgdown_steps <- cr_buildstep_pkgdown("$_GITHUB_REPO",
                                        "cloudbuild@google.com")

  expect_equal(pkgdown_steps[[1]]$name, "gcr.io/cloud-builders/gcloud")
  expect_equal(pkgdown_steps[[1]]$args[[1]], "kms")
  expect_equal(pkgdown_steps[[1]]$args[[4]], "id_rsa.enc")
  expect_equal(pkgdown_steps[[1]]$args[[10]], "my-keyring")
  expect_equal(pkgdown_steps[[1]]$volumes[[1]]$name, "ssh")
  expect_equal(pkgdown_steps[[1]]$volumes[[1]]$path, "/root/.ssh")

  expect_equal(pkgdown_steps[[4]]$args[[3]],
               "devtools::install()\nlist.files()\npkgdown::build_site()\n")

  gh <- GitHubEventsConfig("mark/repo")
  expect_equal(gh$owner, "mark")
  expect_equal(gh$name, "repo")
  expect_equal(gh$push$branch, ".*")

})



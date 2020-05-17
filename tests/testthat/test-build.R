context("Online tests")

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

test_that("[Online] Test deployments", {
  skip_on_travis()
  skip_on_cran()
  runme <- system.file("example/",
                       package="googleCloudRunner",
                       mustWork=TRUE)

  cd <- cr_deploy_docker(runme, launch_browser = FALSE)
  expect_equal(cd$status,"SUCCESS")

  # why fail?
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

})

test_that("[Online] Test schedule jobs", {
  skip_on_travis()
  skip_on_cran()
  cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
                            package = "googleCloudRunner")
  build1 <- cr_build_make(cloudbuild)

  id <- "cloud-build-test1-zzzzz"
  fid <-
    "projects/mark-edmondson-gde/locations/europe-west1/jobs/cloud-build-test1-zzzzz"

  # in case a failed test run left it up
  try(cr_schedule_delete(id))

  s1 <- cr_schedule(name=id, schedule = "11 11 * * *",
              httpTarget = cr_build_schedule_http(build1))
  expect_equal(s1$name, fid)

  s2 <- cr_schedule_get(id)
  expect_equal(s1$name, s2$name)

  s3 <- cr_schedule_pause(s1)
  expect_equal(s3$state, "PAUSED")
  s4 <- cr_schedule_resume(s3)
  expect_equal(s4$state, "ENABLED")
  s5 <- cr_schedule_run(s4)
  expect_equal(s5$state, "ENABLED")
  new_list <- cr_schedule_list()
  expect_true(s4$name %in% new_list$name)
  s6 <- cr_schedule(name=id, description = "edited", overwrite = TRUE)
  expect_equal(s6$description, "edited")
  deleteme <- cr_schedule_delete(id)
  expect_true(deleteme)
  newer_list <- cr_schedule_list()
  expect_true(!s4$name %in% newer_list$name)

})



test_that("[Online] Test Build Triggers",{
  skip_on_travis()
  skip_on_cran()
  cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
                            package = "googleCloudRunner")

  bb <- cr_build_make(cloudbuild)

  github <- GitHubEventsConfig("MarkEdmondson1234/googleCloudRunner",
                               branch = "master")


  ss <- list(`_MYVAR` = "TEST1",
             `_GITHUB` = "MarkEdmondson1234/googleCloudRunner")

  bt1 <- cr_buildtrigger("trig1",
                         trigger = github,
                         build = bb,
                         substitutions = ss)
  expect_equal(bt1$name, "trig1")
  bt11 <- cr_buildtrigger_get(bt1)
  expect_equal(bt11$name, "trig1")

  bt2 <- cr_buildtrigger("trig2",
                         trigger = github,
                         build = "inst/cloudbuild/cloudbuild.yaml")
  expect_equal(bt2$github$owner, "MarkEdmondson1234")
  expect_equal(bt2$filename, "inst/cloudbuild/cloudbuild.yaml")

  # needs to be mirrored from GitHub or created with Google Cloud Repositories
  repo <- RepoSource("googleCloudStorageR",
                     projectId = cr_project_get(),
                     tagName = "v0.5.1")
  gcs_repo <- "gcs-repo-test1zzzz"
  my_build <- cr_build_make(
    cr_build_yaml(steps = cr_buildstep_r("list.files()"))
  )

  bt_repo <- cr_buildtrigger(
    gcs_repo,
    trigger = repo,
    build = my_build
  )

  new_list <- cr_buildtrigger_list()

  expect_true(bt1$id %in% new_list$id)
  expect_true(bt2$id %in% new_list$id)
  expect_true(bt2$name %in% new_list$name)
  expect_true(bt_repo$id %in% new_list$id)

  my_build2 <- cr_build_make(
    cr_build_yaml(steps = cr_buildstep_r("list.files(full.names=TRUE)"))
    )

  bt3 <- cr_buildtrigger_make(
    trigger = repo,
    build = my_build2,
    name = "edited1",
    tags = "edit",
    disabled = TRUE,
    description = "edited trigger"
  )
  edited <- cr_buildtrigger_edit(bt3, triggerId = bt_repo)

  washup1 <- cr_buildtrigger_delete(bt1)
  washup2 <- cr_buildtrigger_delete(bt2$id)
  expect_true(washup1)
  expect_true(washup2)

  newer_list <- cr_buildtrigger_list()

  expect_true(edited$id %in% newer_list$id)
  expect_true(!bt1$id %in% newer_list$id)
  expect_true(!bt2$id %in% newer_list$id)
  expect_true(!bt2$name %in% newer_list$name)

  washup3 <- cr_buildtrigger_delete(edited)
  expect_true(washup3)

})

test_that("Test Source Repo functions", {
  skip_on_travis()
  skip_on_cran()

  sr <- cr_sourcerepo_list()

  expect_s3_class(sr, "data.frame")
})

test_that("Test build artifacts", {
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

context("Offline tests")

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
                images = "gcr.io/my-project/demo")
  expect_true(googleCloudRunner:::is.gar_Build(bq))
  expect_equal(bq$images, "gcr.io/my-project/demo")
  expect_equal(bq$timeout, "10s")
  expect_equal(bq$steps[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(bq$steps[[2]]$name, "alpine")
  expect_equal(bq$source$storageSource$bucket, "gs://my-bucket")

  bq2 <- cr_build_make(yaml = yaml,
                      source = my_repo_source,
                      timeout = "11s",
                      images = "gcr.io/my-project/demo")
  expect_true(googleCloudRunner:::is.gar_Build(bq2))
  expect_equal(bq2$images, "gcr.io/my-project/demo")
  expect_equal(bq2$timeout, "11s")
  expect_equal(bq2$steps[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(bq2$steps[[2]]$name, "alpine")
  expect_equal(bq2$source$repoSource$branchName, "master")

  # write from creating a Yaml object
  image <- "gcr.io/my-project/my-image"
  run_yaml <- cr_build_yaml(steps = c(cr_buildstep_docker(image, dir = "deploy"),
                             cr_buildstep("gcloud",
                                          c("beta","run","deploy", "test1",
                                            "--image", image), dir="deploy")),
     images = image)

  expect_equal(run_yaml$images[[1]], image)
  expect_equal(run_yaml$steps[[1]]$dir, "deploy")
  expect_equal(run_yaml$steps[[1]]$args[[5]],
               "gcr.io/my-project/my-image:$BUILD_ID")
  expect_equal(run_yaml$steps[[2]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(run_yaml$steps[[2]]$args[[2]],
               "gcr.io/my-project/my-image:$BUILD_ID")
  expect_equal(run_yaml$steps[[3]]$args[[1]], "beta")

  scheduler <- cr_build_schedule_http(cr_build_make(run_yaml))

  expect_equal(scheduler$body, "eyJzdGVwcyI6W3sibmFtZSI6Imdjci5pby9jbG91ZC1idWlsZGVycy9kb2NrZXIiLCJhcmdzIjpbImJ1aWxkIiwiLWYiLCJEb2NrZXJmaWxlIiwiLXQiLCJnY3IuaW8vbXktcHJvamVjdC9teS1pbWFnZTokQlVJTERfSUQiLCIuIl0sImRpciI6ImRlcGxveSJ9LHsibmFtZSI6Imdjci5pby9jbG91ZC1idWlsZGVycy9kb2NrZXIiLCJhcmdzIjpbInB1c2giLCJnY3IuaW8vbXktcHJvamVjdC9teS1pbWFnZTokQlVJTERfSUQiXSwiZGlyIjoiZGVwbG95In0seyJuYW1lIjoiZ2NyLmlvL2Nsb3VkLWJ1aWxkZXJzL2djbG91ZCIsImFyZ3MiOlsiYmV0YSIsInJ1biIsImRlcGxveSIsInRlc3QxIiwiLS1pbWFnZSIsImdjci5pby9teS1wcm9qZWN0L215LWltYWdlIl0sImRpciI6ImRlcGxveSJ9XSwiaW1hZ2VzIjpbImdjci5pby9teS1wcm9qZWN0L215LWltYWdlIl19")

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
  expect_equal(bsd[[1]]$args[[5]], "gcr.io/test-project/my-image:$BRANCH_NAME")
  expect_equal(bsd[[2]]$name,  "gcr.io/cloud-builders/docker")
  expect_equal(bsd[[2]]$args[[1]], "push")

  y <- data.frame(name = c("docker", "alpine"),
                  args = I(list(c("version"), c("echo", "Hello Cloud Build"))),
                  id = c("Docker Version", "Hello Cloud Build"),
                  prefix = c(NA, ""),
                  stringsAsFactors = FALSE)
  bsy <- cr_buildstep_df(y)
  expect_equal(bsy[[1]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(bsy[[1]]$args[[1]], "version")
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
  expect_equal(edit2[[1]]$args[[1]], "blah")
  expect_equal(edit3[[1]]$name, "gcr.io/blah")
  expect_equal(edit4[[1]]$dir, "blah")

  git_yaml <- cr_build_yaml(
    steps = c(
      cr_buildstep_gitsetup("github-ssh"),
      cr_buildstep_git(c("clone", "git@github.com:github_name/repo_name"))
    )
  )

  expect_equal(git_yaml$steps[[1]]$name, "gcr.io/cloud-builders/gcloud")
  expect_equal(git_yaml$steps[[1]]$args[[1]], "-c")
  expect_equal(git_yaml$steps[[1]]$args[[2]],
               "gcloud secrets versions access latest --secret=github-ssh > /root/.ssh/id_rsa")
  expect_equal(git_yaml$steps[[1]]$volumes[[1]]$name, "ssh")
  expect_equal(git_yaml$steps[[1]]$volumes[[1]]$path, "/root/.ssh")

  expect_equal(git_yaml$steps[[2]]$name, "gcr.io/cloud-builders/git")
  expect_equal(git_yaml$steps[[2]]$volumes[[1]]$name, "ssh")
  expect_equal(git_yaml$steps[[2]]$volumes[[1]]$path, "/root/.ssh")

  pkgdown_steps <- cr_buildstep_pkgdown("$_GITHUB_REPO",
                                        "cloudbuild@google.com",
                                        "my_secret")

  expect_equal(pkgdown_steps[[1]]$name,
               "gcr.io/cloud-builders/gcloud")
  expect_equal(pkgdown_steps[[1]]$args[[2]],
               "gcloud secrets versions access latest --secret=my_secret > /root/.ssh/id_rsa")
  expect_equal(pkgdown_steps[[2]]$id, "git setup script")
  expect_equal(pkgdown_steps[[3]]$args[[1]], "clone")
  expect_equal(pkgdown_steps[[3]]$volumes[[1]]$name, "ssh")
  expect_equal(pkgdown_steps[[3]]$volumes[[1]]$path, "/root/.ssh")

  expect_equal(pkgdown_steps[[4]]$args[[3]],
               "devtools::install()\npkgdown::build_site()")

  expect_equal(pkgdown_steps[[5]]$args[[1]],
               "add")
  expect_equal(pkgdown_steps[[6]]$args[[1]],
               "commit")
  expect_equal(pkgdown_steps[[6]]$args[[4]],
               "[skip travis] Build website from commit ${COMMIT_SHA}: \n$(date +\"%Y%m%dT%H:%M:%S\")")
  expect_equal(pkgdown_steps[[7]]$args[[1]],
               "status")
  expect_equal(pkgdown_steps[[8]]$args[[1]],
               "push")

  gh <- GitHubEventsConfig("mark/repo")
  expect_equal(gh$owner, "mark")
  expect_equal(gh$name, "repo")
  expect_equal(gh$push$branch, ".*")

  # use your own R image with custom R
  my_r <- c("devtools::install()", "pkgdown::build_site()")
  br <-  cr_buildstep_r(my_r, name = "gcr.io/gcer-public/packagetools:master")
  expect_equal(br[[1]]$args[[3]], "devtools::install()\npkgdown::build_site()")

  bs <- cr_build_yaml(steps = cr_buildstep_bash("echo Hello"))
  expect_equal(bs$steps[[1]]$args[[3]], "echo Hello")

  mg <- cr_build_yaml(steps =
                        cr_buildstep_mailgun("Hello from Cloud Build",
                                             "x@x.me",
                                             "Hello",
                                             "googleCloudRunner@example.com"),
                      substitutions = list(
                        `_MAILGUN_URL` = "blah",
                        `_MAILGUN_KEY` = "poo"))

  expect_equal(mg$steps[[1]]$args[[3]],
               "httr::POST(paste0(\"$_MAILGUN_URL\",\"/messages\"),\n           httr::authenticate(\"api\", \"$_MAILGUN_KEY\"),\n           encode = \"form\",\n           body = list(\n             from=\"googleCloudRunner@example.com\",\n             to=\"x@x.me\",\n             subject=\"Hello\",\n             text=\"Hello from Cloud Build\"\n           ))")
  expect_equal(mg$substitutions$`_MAILGUN_URL`, "blah")


  # pkgdown builds
  pd <- cr_deploy_pkgdown(secret = "my_github")
  expect_true(file.exists("cloudbuild-pkgdown.yml"))
  expect_equal(pd$steps[[1]]$name, "gcr.io/cloud-builders/gcloud")
  expect_equal(pd$steps[[1]]$args[[2]],
    "gcloud secrets versions access latest --secret=my_github > /root/.ssh/id_rsa")
  unlink("cloudbuild-pkgdown.yml")

  # package test builds
  pt <- cr_deploy_packagetests()
  expect_true(file.exists("cloudbuild-tests.yml"))
  expect_equal(pt$steps[[1]]$env[[1]], "NOT_CRAN=true")
  unlink("cloudbuild-tests.yml")

  # slack messages
  bs <- cr_buildstep_slack("hello")
  expect_equal(bs[[1]]$name, "technosophos/slack-notify")
  expect_equal(bs[[1]]$env[[1]], "SLACK_WEBHOOK=$_SLACK_WEBHOOK")
  expect_equal(bs[[1]]$env[[2]], "SLACK_MESSAGE='hello'")

  # secrets
  ss <- cr_buildstep_secret("my_secret","secret.json")
  expect_equal(ss[[1]]$name, "gcr.io/cloud-builders/gcloud")
  expect_equal(ss[[1]]$entrypoint, "bash")
  expect_equal(ss[[1]]$args[[2]], "gcloud secrets versions access latest --secret=my_secret > secret.json")

})



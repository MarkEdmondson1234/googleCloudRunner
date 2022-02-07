test_that("Render BuildStep objects", {
  bs1 <- cr_buildstep("alpine", c("-c", "ls -la"), entrypoint = "bash", prefix = "")
  expect_snapshot_output(bs1)

  cloudbuild_dc <- cr_buildstep_decrypt("secret.json.enc",
    plain = "secret.json",
    keyring = "my_keyring",
    key = "my_key"
  )
  expect_snapshot_output(cloudbuild_dc)

  bsd <- cr_buildstep_docker("my-image", tag = "$BRANCH_NAME")
  expect_snapshot_output(bsd)

  y <- data.frame(
    name = c("docker", "alpine"),
    args = I(list(c("version"), c("echo", "Hello Cloud Build"))),
    id = c("Docker Version", "Hello Cloud Build"),
    prefix = c(NA, ""),
    stringsAsFactors = FALSE
  )
  bsy <- cr_buildstep_df(y)
  expect_snapshot_output(bsy)

  package_build <- system.file("cloudbuild/cloudbuild_packages.yml",
    package = "googleCloudRunner"
  )
  bp <- cr_build_make(package_build)
  bp1 <- cr_buildstep_extract(bp, step = 2)
  bp2 <- cr_buildstep_extract(bp, step = 3)
  expect_snapshot_output(bp1)
  expect_snapshot_output(bp2)

  edit1 <- cr_buildstep_edit(bp2, name = "blah")
  edit2 <- cr_buildstep_edit(bp2, args = "blah")
  edit3 <- cr_buildstep_edit(bp2, name = "gcr.io/blah")
  edit4 <- cr_buildstep_edit(bp2, dir = "blah")

  expect_snapshot_output(edit1)
  expect_snapshot_output(edit2)
  expect_snapshot_output(edit3)
  expect_snapshot_output(edit4)

  git_yaml <- cr_build_yaml(
    steps = c(
      cr_buildstep_gitsetup("github-ssh"),
      cr_buildstep_git(c("clone", "git@github.com:github_name/repo_name"))
    )
  )

  expect_snapshot_output(git_yaml)

  pkgdown_steps <- cr_buildstep_pkgdown(
    "$_GITHUB_REPO",
    "cloudbuild@google.com",
    "my_secret"
  )

  expect_snapshot_output(pkgdown_steps)

  gh <- GitHubEventsConfig("mark/repo")
  expect_snapshot_output(gh)

  # use your own R image with custom R
  my_r <- c("devtools::install()", "pkgdown::build_site()")
  br <- cr_buildstep_r(my_r, name = "gcr.io/gcer-public/packagetools:latest")
  expect_snapshot_output(br)

  bs <- cr_build_yaml(steps = cr_buildstep_bash("echo Hello"))
  expect_equal(bs$steps[[1]]$args[[3]], "echo Hello")

  mg <- cr_build_yaml(
    steps =
      cr_buildstep_mailgun(
        "Hello from Cloud Build",
        "x@x.me",
        "Hello",
        "googleCloudRunner@example.com"
      ),
    substitutions = list(
      `_MAILGUN_URL` = "blah",
      `_MAILGUN_KEY` = "poo"
    )
  )

  expect_snapshot_output(mg)


  # pkgdown builds
  pd <- cr_deploy_pkgdown("MarkEdmondson1234/googleCloudRunner",
    secret = "my_github",
    create_trigger = "no"
  )
  expect_true(file.exists("cloudbuild-pkgdown.yml"))
  expect_snapshot_output(pd)
  unlink("cloudbuild-pkgdown.yml")

  # package test builds
  pt <- cr_deploy_packagetests(create_trigger = "no")
  expect_true(file.exists("cloudbuild-tests.yml"))
  expect_equal(pt$steps[[1]]$env[[1]], "NOT_CRAN=true")
  expect_snapshot_output(pt)
  unlink("cloudbuild-tests.yml")

  # slack messages
  bs <- cr_buildstep_slack("hello")
  expect_snapshot_output(bs)

  # secrets
  ss <- cr_buildstep_secret("my_secret", "secret.json")
  expect_snapshot_output(ss)

  # kaniko
  kaniko <- cr_buildstep_docker("my-image",
    kaniko_cache = TRUE,
    projectId = "test-project"
  )
  expect_snapshot_output(kaniko)

  # build triggers
  gh_trigger <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner",
    type = "github"
  )
  expect_s3_class(gh_trigger, "cr_buildtrigger_repo")
  expect_snapshot_output(gh_trigger)

  cs_trigger <- cr_buildtrigger_repo("github_markedmondson1234_googlecloudrunner",
    type = "cloud_source",
    projectId = "my-project"
  )

  expect_s3_class(cs_trigger, "cr_buildtrigger_repo")
  expect_snapshot_output(cs_trigger)

  # gcloud
  gc <- cr_buildstep_gcloud("gcloud", "ls")
  expect_s3_class(gc[[1]], "cr_buildstep")
  expect_snapshot_output(gc)

  bq <- cr_buildstep_gcloud("bq", "ls")
  expect_s3_class(bq[[1]], "cr_buildstep")
  expect_snapshot_output(bq)

  kk <- cr_buildstep_gcloud("kubectl", "ls")
  expect_s3_class(kk[[1]], "cr_buildstep")
  expect_snapshot_output(kk)

  # r script from bucket
  rr <- cr_buildstep_r("gs://my-bucket/script.R")

  expect_s3_class(rr[[1]], "cr_buildstep")
  expect_s3_class(rr[[2]], "cr_buildstep")
  expect_snapshot_output(rr)

  # setup nginx
  ff <- cr_buildstep_nginx_setup("folder")

  expect_s3_class(ff[[1]], "cr_buildstep")
  expect_snapshot_output(ff)

  # pubsub topic target
  top <- cr_schedule_pubsub("test-topic")
  expect_snapshot_output(top)

  # pubsub config for buildtriggers
  top2 <- cr_buildtrigger_pubsub("test-topic")
  expect_snapshot_output(top2)
})

test_that("Conversions to GitRepoSource", {
  gh <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner",
                             branch = "master")

  gh2 <- as.gitRepoSource(gh)
  expect_true(is.gitRepoSource(gh2))

  cs <- cr_buildtrigger_repo("github_markedmondson1234_googlecloudrunner",
                             type = "cloud_source", branch = NULL, tag = "v1.1",
                             projectId = "my-project")

  cs2 <- as.gitRepoSource(cs)
  expect_true(is.gitRepoSource(cs2))

})

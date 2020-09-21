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
  Sys.sleep(10) # pause to allow time for schedule list to update
  new_list <- cr_schedule_list()
  expect_true(s4$name %in% new_list$name)
  s6 <- cr_schedule(name=id, description = "edited", overwrite = TRUE)
  expect_equal(s6$description, "edited")
  deleteme <- cr_schedule_delete(id)
  expect_true(deleteme)
  Sys.sleep(10) # pause to allow time for schedule list to update
  newer_list <- cr_schedule_list()
  expect_true(!s4$name %in% newer_list$name)

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



test_that("[Online] Test Build Triggers",{
  skip_on_travis()
  skip_on_cran()
  cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
                            package = "googleCloudRunner")

  bb <- cr_build_make(cloudbuild)

  gh_trigger <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner")
  cs_trigger <- cr_buildtrigger_repo("github_markedmondson1234_googlecloudrunner",
                                     type = "cloud_source")

  # build with in-line build code
  gh_inline <- cr_buildtrigger(bb, name = "bt-github-inline", trigger = gh_trigger)

  # build pointing to cloudbuild.yaml within the GitHub repo
  gh_file <- cr_buildtrigger("inst/cloudbuild/cloudbuild.yaml",
                  name = "bt-github-file", trigger = gh_trigger)

  cs_file <- cr_buildtrigger("inst/cloudbuild/cloudbuild.yaml",
                              name = "bt-cs-file", trigger = cs_trigger)

  # build inline with trigger source
  cloudbuild_rmd <- system.file("cloudbuild/cloudbuild_rmd.yml",
                                 package = "googleCloudRunner")
  b_rmd <- cr_build_make(cloudbuild_rmd)
  gh_source_inline <- cr_buildtrigger(b_rmd,
                                      name = "bt-github-source",
                                      trigger = gh_trigger)
  cs_source_inline <- cr_buildtrigger(b_rmd,
                                      name = "bt-cs-source",
                                      trigger = cs_trigger)
  Sys.sleep(5)
  the_list <- cr_buildtrigger_list()
  expect_true("bt-github-inline" %in% the_list$name)
  expect_true("bt-github-file" %in% the_list$name)
  expect_true("bt-cs-file" %in% the_list$name)
  expect_true("bt-github-source" %in% the_list$name)
  expect_true("bt-cs-source" %in% the_list$name)

  cr_buildtrigger_delete("bt-github-inline")
  cr_buildtrigger_delete("bt-github-file")
  cr_buildtrigger_delete("bt-cs-file")
  cr_buildtrigger_delete("bt-github-source")
  cr_buildtrigger_delete("bt-cs-source")

  Sys.sleep(5)
  the_list2 <- cr_buildtrigger_list()

  expect_false("bt-github-inline" %in% the_list2$name)
  expect_false("bt-github-file" %in% the_list2$name)
  expect_false("bt-cs-file" %in% the_list2$name)
  expect_false("bt-github-source" %in% the_list2$name)
  expect_false("bt-cs-source" %in% the_list2$name)

  an_id <- the_list2[the_list2$name == "package-checks","id"]
  info <- cr_buildtrigger_get(an_id)
  expect_equal(info$name, "package-checks")

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

  expect_s3_class(o, "list")
  expect_equal(o$mean[[1]], 81)
  expect_equal(o$x[[1]], 100)

  all_urls <- c("https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=North%20America&industry=Transportation%20(non-freight)"
  ,"https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=Europe&industry=Transportation%20(non-freight)"
  ,"https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=South%20America&industry=Transportation%20(non-freight)"
  ,"https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=Australia&industry=Transportation%20(non-freight)"
  ,"https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=North%20America&industry=Software")

  res2 <- cr_jwt_async(all_urls, token = token)
  expect_s3_class(res2, "list")
  # response is json starting with {"params" ...}
  expect_true(grepl('^\\{\\"params\\"',res2[[1]]))

})



context("Offline tests")

test_that("JWT creation", {

  test_url <- "https://fake.a.run.app"
  jwt <- cr_jwt_create(test_url)
  expect_equal(jwt, "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImJkOTEwNWFiMjVkOTY1NDI2NzYzYzNlYWYwZGY1NDczMTZiMjdjYTQiLCJhbGcuMSI6IlJTMjU2IiwidHlwLjEiOiJKV1QifQ.eyJpc3MiOiJnb29nbGVjbG91ZHJ1bm5lckBtYXJrLWVkbW9uZHNvbi1nZGUuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJzdWIiOiJnb29nbGVjbG91ZHJ1bm5lckBtYXJrLWVkbW9uZHNvbi1nZGUuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJhdWQiOiJodHRwczovL3d3dy5nb29nbGVhcGlzLmNvbS9vYXV0aDIvdjQvdG9rZW4iLCJleHAiOjE2MDA2NzgxMzgsImlhdCI6MTYwMDY3NDUzOCwidGFyZ2V0X2F1ZGllbmNlIjoiaHR0cHM6Ly9mYWtlLmEucnVuLmFwcCJ9.i2naLHKTxyKo8lglcdr9NakkC4HFvZldjpUJX8DjCjObyi7_QriATlKOlfZcDbTyIIZlKVZI52UisnXtxzgUOdJyrsL5weE9F1yuMM2_LZoj7EyCksgaTNPtoJv4_xosr7Xq_wtzdQJI8Gm0LODxhM8Zx_o8Sy47mJ3x36PlcXIiWzDvoSnigabJIob-qJ4leT871h8ipVJ8hyCXcTuUIzmvoyjjHwNsJuedL8GVT79SE9Mo5v0H9-7tdXDu6f2KCoeCkrtZm_HSWQ1YEgkpYaxOe77vtF3PKaDWXl3gTfEZaWN-E0WPYQTqcazln3Z25yX9ILt206CLoYIybXoClQ")

  token <- cr_jwt_token(jwt, test_url)
  expect_equal(token,
               "eyJhbGciOiJSUzI1NiIsImtpZCI6IjRiODNmMTgwMjNhODU1NTg3Zjk0MmU3NTEwMjI1MTEyMDg4N2Y3MjUiLCJ0eXAiOiJKV1QifQ.eyJhdWQiOiJodHRwczovL2Zha2UuYS5ydW4uYXBwIiwiYXpwIjoiZ29vZ2xlY2xvdWRydW5uZXJAbWFyay1lZG1vbmRzb24tZ2RlLmlhbS5nc2VydmljZWFjY291bnQuY29tIiwiZW1haWwiOiJnb29nbGVjbG91ZHJ1bm5lckBtYXJrLWVkbW9uZHNvbi1nZGUuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiZXhwIjoxNjAwNjc4MTk2LCJpYXQiOjE2MDA2NzQ1OTYsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6IjExNzQzNjQ4OTM0NTk5NjE0Nzk3MyJ9.Qwvjez5ejOHWBEnwc4rCkTogDxwhi_wpuJPUYkYM8Dw2kgfCJeh_xkFiesWsPSRd0_RO161bSNg6xskc9GspwCQOGJK6pj1RA6GCImuRSDuUJsfUl2nfbhYmKBXpvfJVtoKZbBn-Y0WguYQ0NtzTepCpMxHT9YGCpED2xKLWAq3LAQEHwEvZpumdvktzXIQUnuhrQBq6sR9vAvsnbtAgGEB3xSTpExKSmbtoEtXBAdyC2Oqw4XuOC3CH0OMc7tyT9b96BM1Xhk7GmPAqg9YrMvnRH7z7_USFgii9R62F3fC0Vnhk88q-9ARCKoPG_kzB9rKZX3LTKwCweW9S9gjszA")


})

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
               "gcr.io/my-project/my-image:latest")
  expect_equal(run_yaml$steps[[2]]$name, "gcr.io/cloud-builders/docker")
  expect_equal(run_yaml$steps[[2]]$args[[2]],
               "gcr.io/my-project/my-image")
  expect_equal(run_yaml$steps[[3]]$args[[1]], "beta")

  scheduler <- cr_build_schedule_http(cr_build_make(run_yaml))

  expect_equal(scheduler$body, "eyJzdGVwcyI6W3sibmFtZSI6Imdjci5pby9jbG91ZC1idWlsZGVycy9kb2NrZXIiLCJhcmdzIjpbImJ1aWxkIiwiLWYiLCJEb2NrZXJmaWxlIiwiLS10YWciLCJnY3IuaW8vbXktcHJvamVjdC9teS1pbWFnZTpsYXRlc3QiLCItLXRhZyIsImdjci5pby9teS1wcm9qZWN0L215LWltYWdlOiRCVUlMRF9JRCIsIi4iXSwiZGlyIjoiZGVwbG95In0seyJuYW1lIjoiZ2NyLmlvL2Nsb3VkLWJ1aWxkZXJzL2RvY2tlciIsImFyZ3MiOlsicHVzaCIsImdjci5pby9teS1wcm9qZWN0L215LWltYWdlIl0sImRpciI6ImRlcGxveSJ9LHsibmFtZSI6Imdjci5pby9jbG91ZC1idWlsZGVycy9nY2xvdWQiLCJhcmdzIjpbImJldGEiLCJydW4iLCJkZXBsb3kiLCJ0ZXN0MSIsIi0taW1hZ2UiLCJnY3IuaW8vbXktcHJvamVjdC9teS1pbWFnZSJdLCJkaXIiOiJkZXBsb3kifV0sImltYWdlcyI6WyJnY3IuaW8vbXktcHJvamVjdC9teS1pbWFnZSJdfQ==")

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
  expect_equal(bsd[[1]]$args[[4]], "--tag")
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
  br <-  cr_buildstep_r(my_r, name = "gcr.io/gcer-public/packagetools:latest")
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
  pd <- cr_deploy_pkgdown("MarkEdmondson1234/googleCloudRunner",
                          secret = "my_github",
                          create_trigger = "no")
  expect_true(file.exists("cloudbuild-pkgdown.yml"))
  expect_equal(pd$steps[[1]]$name, "gcr.io/cloud-builders/gcloud")
  expect_equal(pd$steps[[1]]$args[[2]],
    "gcloud secrets versions access latest --secret=my_github > /root/.ssh/id_rsa")
  unlink("cloudbuild-pkgdown.yml")

  # package test builds
  pt <- cr_deploy_packagetests(create_trigger = "no")
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
  expect_equal(ss[[1]]$args[[2]],
      "gcloud secrets versions access latest --secret=my_secret > secret.json")

  # kaniko
  kaniko <- cr_buildstep_docker("my-image", kaniko_cache = TRUE,
                                projectId = "test-project")
  expect_equal(kaniko[[1]]$name, "gcr.io/kaniko-project/executor:latest")
  expect_equal(kaniko[[2]]$name, "gcr.io/kaniko-project/executor:latest")
  expect_equal(kaniko[[2]]$args[[4]],
               "gcr.io/test-project/my-image:$BUILD_ID")
  expect_equal(kaniko[[1]]$args[[5]], "--context=dir:///workspace/")
  expect_equal(kaniko[[1]]$args[[6]], "--cache=true")

  # build triggers
  gh_trigger <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner",
                                     type = "github")
  expect_s3_class(gh_trigger, "cr_buildtrigger_repo")
  expect_equal(gh_trigger$type, "github")
  expect_equal(gh_trigger$repo$name, "googleCloudRunner")

  cs_trigger <- cr_buildtrigger_repo("github_markedmondson1234_googlecloudrunner",
                                     type = "cloud_source")

  expect_s3_class(cs_trigger, "cr_buildtrigger_repo")
  expect_equal(cs_trigger$type, "cloud_source")
  expect_equal(cs_trigger$repo$repoName,
               "github_markedmondson1234_googlecloudrunner")

  #gcloud
  gc <- cr_buildstep_gcloud("gcloud","ls")
  expect_s3_class(gc[[1]], "cr_buildstep")
  expect_equal(gc[[1]]$name, "gcr.io/google.com/cloudsdktool/cloud-sdk:alpine")
  expect_equal(gc[[1]]$args[[1]], "ls")

  bq <- cr_buildstep_gcloud("bq","ls")
  expect_s3_class(bq[[1]], "cr_buildstep")
  expect_equal(bq[[1]]$name, "gcr.io/google.com/cloudsdktool/cloud-sdk:alpine")
  expect_equal(bq[[1]]$entrypoint, "bq")
  expect_equal(bq[[1]]$args[[1]], "ls")

  kk <- cr_buildstep_gcloud("kubectl","ls")
  expect_s3_class(kk[[1]], "cr_buildstep")
  expect_equal(kk[[1]]$name, "gcr.io/google.com/cloudsdktool/cloud-sdk:latest")

  # r script from bucket
  rr <- cr_buildstep_r("gs://my-bucket/script.R")

  expect_s3_class(rr[[1]], "cr_buildstep")
  expect_s3_class(rr[[2]], "cr_buildstep")
  expect_equal(rr[[1]]$name, "gcr.io/google.com/cloudsdktool/cloud-sdk:alpine")
  expect_equal(rr[[1]]$args, c("cp","gs://my-bucket/script.R","/workspace/script.R"))
  expect_equal(rr[[2]]$name, "rocker/r-base")
  expect_equal("rocker/r-base", c("Rscript", "/workspace/script.R"))

  # setup nginx
  ff <- cr_buildstep_nginx_setup("folder")

  expect_s3_class(ff[[1]], "cr_buildstep")
  expect_equal(ff[[1]]$name, "ubuntu")
  expect_equal(ff[[1]]$args[[1]], "bash")
  expect_equal(ff[[1]]$dir, "folder")

})



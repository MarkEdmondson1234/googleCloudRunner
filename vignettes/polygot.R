library(googleCloudRunner)
polygot <- cr_build_yaml(
  steps = c(
    cr_buildstep(
      id = "download encrypted auth file",
      name = "gsutil",
      args = c("cp",
               "gs://marks-bucket-of-stuff/auth.json.enc",
               "/workspace/auth.json.enc"),
    ),
    cr_buildstep_decrypt(
      id = "decrypt file",
      cipher = "/workspace/auth.json.enc",
      plain = "/workspace/auth.json",
      keyring = "my-keyring",
      key = "ga_auth"
    ),
    cr_buildstep(
      id = "download google analytics",
      name = "gcr.io/gcer-public/gago:master",
      env = c("GAGO_AUTH=/workspace/auth.json"),
      args = c("reports",
               "--view=81416156",
               "--dims=ga:date,ga:medium",
               "--mets=ga:sessions",
               "--start=2014-01-01",
               "--end=2019-11-30",
               "--antisample",
               "--max=-1",
               "-o=google_analytics.csv"),
      dir = "build"
    ),
    cr_buildstep(
      id = "download Rmd template",
      name = "gsutil",
      args = c("cp",
               "gs://mark-edmondson-public-read/polygot.Rmd",
               "/workspace/build/polygot.Rmd")
    ),
    cr_buildstep_r(
      id="render rmd",
      r = "lapply(list.files('.', pattern = '.Rmd', full.names = TRUE),
             rmarkdown::render, output_format = 'html_document')",
      name = "gcr.io/gcer-public/packagetools:latest",
      dir = "build"
      ),
    cr_buildstep_bash(
      id = "setup nginx",
      bash_script = system.file("docker", "nginx", "setup.bash",
                                package = "googleCloudRunner"),
      dir = "build"
      ),
    cr_buildstep_docker(
      # change to your own container registry
      image = "gcr.io/gcer-public/polygot_demo",
      tag = "latest",
      dir = "build"
      ),
    cr_buildstep_run(
      name = "polygot-demo",
      image = "gcr.io/gcer-public/polygot_demo",
      concurrency = 80),
    cr_buildstep(
      id = "load BigQuery",
      name = "gcr.io/google.com/cloudsdktool/cloud-sdk:alpine",
      entrypoint = "bq",
      args = c("--location=EU",
               "load",
               "--autodetect",
               "--source_format=CSV",
               "test_EU.polygot",
               "google_analytics.csv"
               ),
      dir = "build"
    )
  )
)

# build the polygot cloud build steps
build <- cr_build(polygot)
built <- cr_build_wait(build)



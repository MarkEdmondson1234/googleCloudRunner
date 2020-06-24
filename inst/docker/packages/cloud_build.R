# for scheduled builds
library(googleCloudRunner)

# it needs to use the github source
bs <- c(
  cr_buildstep_gitsetup("github-ssh"),
  cr_buildstep_git(c("clone","git@github.com:MarkEdmondson1234/googleCloudRunner",".")),
  cr_buildstep_docker("gcr.io/gcer-public/packagetools",
                      dir = "inst/docker/packages/")
)

built <- cr_build(cr_build_yaml(bs, timeout = 1200))

s_me <- cr_build_schedule_http(built)
cr_schedule("packagetest-build", schedule = "15 9 * * 1", httpTarget = s_me)

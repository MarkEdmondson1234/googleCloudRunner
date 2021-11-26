remotes::install_deps(dependencies = TRUE)
remotes::install_local()
cv <- covr::package_coverage()
up <- covr::codecov(coverage = cv,
              commit = "$COMMIT_SHA", branch = "$BRANCH_NAME",
              quiet = FALSE)
up
if (!up$uploaded) stop("Error uploading codecov reports")

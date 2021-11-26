message("cran mirror: ", getOption("repos"))
remotes::install_deps(dependencies = TRUE)
rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")

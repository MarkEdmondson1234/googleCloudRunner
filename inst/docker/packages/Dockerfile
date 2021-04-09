FROM rocker/verse:latest

RUN install2.r --error \
    -r 'http://cran.rstudio.com' \
    covr \
    deepdep \
    goodpractice \
    httr \
    lintr \
    pkgdown \
    plumber \
    rcmdcheck \
    remotes \
    rhub \
    rmarkdown

# fork with googleCloudRunner support
RUN installGithub.r -r https://cloud.r-project.org MarkEdmondson1234/covr

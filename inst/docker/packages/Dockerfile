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
    rmarkdown \
    markdown

# fork with googleCloudRunner support
RUN installGithub.r \
    -r 'http://cran.rstudio.com' \
    MarkEdmondson1234/covr \
    r-lib/revdepcheck

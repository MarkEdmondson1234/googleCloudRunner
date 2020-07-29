FROM rocker/shiny

# install R package dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev libssl-dev \
    ## clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/ \
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

## Install packages from CRAN
RUN install2.r --error \
    -r 'http://cran.rstudio.com' \
    googleAuthR googleLanguageR googleCloudVisionR

COPY shiny-customized.config /etc/shiny-server/shiny-server.conf
COPY app.R /srv/shiny-server/app.R

EXPOSE 8080

USER shiny

# avoid s6 initialization
# see https://github.com/rocker-org/shiny/issues/79
CMD ["/usr/bin/shiny-server"]

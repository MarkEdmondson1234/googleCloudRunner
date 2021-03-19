FROM rstudio/plumber
RUN install2.r --error \
    -r 'http://cran.rstudio.com' \
    googleAnalyticsR readr knitr

COPY ["./", "./"]
ENTRYPOINT ["Rscript", "server.R"]

FROM gcr.io/gcer-public/googlecloudrunner:master
COPY ["./", "./"]
ENTRYPOINT ["R", "-e","library(plumber);pr("api.R") %>% pr_run(port=as.numeric(Sys.getenv('PORT')))"]
CMD ["api.R"]

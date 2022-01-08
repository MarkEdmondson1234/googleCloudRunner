FROM gcr.io/gcer-public/googlecloudrunner:master
RUN ["install2.r", "ranger", "modeldata", "workflows", "parsnip"]
RUN ["installGithub.r", "tidymodels/vetiver"]
COPY ["./", "./"]
ENTRYPOINT ["Rscript", "server.R"]


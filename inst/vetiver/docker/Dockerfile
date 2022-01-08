FROM gcr.io/gcer-public/googlecloudrunner:master
RUN ["install2.r", "arrow"]
RUN ["install2.r", "pins"]
RUN ["install2.r", "workflows", "parsnip"]
RUN ["install2.r", "modeldata"]
RUN ["install2.r", "ranger"]
RUN ["installGithub.r", "tidymodels/vetiver"]
COPY ["./", "./"]
ENTRYPOINT ["Rscript", "server.R"]


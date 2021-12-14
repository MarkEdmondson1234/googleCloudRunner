FROM gcr.io/gcer-public/targets

WORKDIR /project
COPY renv.lock renv.lock
RUN R -e 'renv::restore()'

FROM rocker/r-ver

# install R package dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev libssl-dev libxml2-dev libzmq3-dev \
    libglpk40 build-essential

RUN ["install2.r", "targets", "renv"]

WORKDIR /usr/local/
COPY . ./

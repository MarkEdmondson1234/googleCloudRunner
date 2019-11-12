FROM rocker/r-ver:latest
LABEL maintainer="mark"
RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
  && apt-get install -y git-core \
	libssl-dev \
	zlib1g-dev
RUN ["install2.r", "assertthat", "cloudRunner", "containerit", "remotes" ,"googleAuthR", "googleCloudStorageR", "jsonlite", "methods", "openssl", "plumber", "remotes", "stats", "utils", "yaml"]
RUN ["installGithub.r", "o2r-project/containerit@master", "r-hub/sysreqs@master"]
WORKDIR /payload/
CMD ["R"]

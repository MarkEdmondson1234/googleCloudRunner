FROM rocker/r-apt:bionic

# install your custom stuff here
RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
  && apt-get install -y git-core \
	zlib1g-dev \
	libxml2-dev \
	libssl-dev \
	libcurl4-openssl-dev
RUN ["install2.r", "googleCloudStorageR", "openssl", "plumber", "remotes", "yaml"]
RUN ["installGithub.r", "MarkEdmondson1234/googleCloudRunner"]

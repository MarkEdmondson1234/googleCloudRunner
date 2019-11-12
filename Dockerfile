FROM gcr.io/mark-edmondson-gde/googleauthr
LABEL maintainer="mark"
RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
  && apt-get install -y git-core \
	zlib1g-dev
RUN ["install2.r", "containerit", "googleCloudStorageR", "openssl", "plumber", "remotes", "yaml"]
RUN ["installGithub.r", "o2r-project/containerit@master", "r-hub/sysreqs@master", "MarkEdmondson1234/cloudRunner"]
WORKDIR /payload/
CMD ["R"]

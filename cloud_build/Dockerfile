FROM gcr.io/mark-edmondson-gde/googleauthr
LABEL maintainer="mark"
RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
  && apt-get install -y git-core \
	zlib1g-dev \
	libxml2-dev
RUN ["install2.r", "googleCloudStorageR", "openssl", "plumber", "remotes", "yaml"]
RUN ["installGithub.r", "MarkEdmondson1234/googleCloudRunner"]
WORKDIR /payload/
CMD ["R"]

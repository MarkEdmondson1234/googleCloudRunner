FROM gcr.io/mark-edmondson-gde/googleauthr
LABEL maintainer="mark"
RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
  && apt-get install -y gcc-9-base libgcc-9-dev libc6-dev \
  libgit2-dev git-core \
	zlib1g \
	libxml2 \
	libsodium-dev
RUN ["install2.r", "googleCloudStorageR", "openssl", "plumber", "remotes", "yaml"]
RUN ["installGithub.r", "MarkEdmondson1234/googleCloudRunner"]
WORKDIR /payload/
CMD ["R"]

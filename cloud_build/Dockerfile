FROM gcr.io/mark-edmondson-gde/googleauthr
LABEL maintainer="mark"
RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
  && apt-get install -y \
  libasan5 \
  gcc-9-base libgcc-9 libc6 \
  libgit2 git-core \
	zlib1g \
	libxml2 \
	libsodium
RUN ["install2.r", "googleCloudStorageR", "openssl", "plumber", "remotes", "yaml"]
RUN ["installGithub.r", "MarkEdmondson1234/googleCloudRunner"]
CMD ["R"]

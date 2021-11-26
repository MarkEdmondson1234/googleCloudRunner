FROM gcr.io/gcer-public/googlecloudrunner:master
RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
  && apt-get install -y git-core \
	libcurl4-openssl-dev \
	libssl-dev \
	make \
	pandoc \
	pandoc-citeproc \
	zlib1g-dev
RUN ["install2.r", "rmarkdown"]

COPY ["./", "./"]
ENTRYPOINT ["Rscript", "server.R"]


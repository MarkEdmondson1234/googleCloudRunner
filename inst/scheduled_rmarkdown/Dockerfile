FROM rocker/verse
LABEL maintainer="mark"
RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
  && apt-get install -y git-core \
	libcurl4-openssl-dev \
	libssl-dev \
	make \
	pandoc \
	pandoc-citeproc \
	zlib1g-dev
RUN ["install2.r", "assertthat", "backports", "cellranger", "colorspace", "crayon", "crosstalk", "curl", "data.table", "digest", "dplyr", "evaluate", "fastmap", "flexdashboard", "fs", "gargle", "ggplot2", "glue", "googlesheets4", "gtable", "htmltools", "htmlwidgets", "httpuv", "httr", "jsonlite", "knitr", "labeling", "later", "lazyeval", "lifecycle", "magrittr", "mime", "munsell", "pillar", "pkgconfig", "plotly", "promises", "purrr", "R6", "Rcpp", "rlang", "rmarkdown", "scales", "shiny", "stringi", "stringr", "tibble", "tidyr", "tidyselect", "vctrs", "viridisLite", "withr", "xfun", "xtable", "yaml", "zeallot"]
WORKDIR /payload/
CMD ["R"]

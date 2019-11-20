# googleCloudRunner

[![Build Status](https://travis-ci.org/MarkEdmondson1234/cloudRunner.svg?branch=master)](https://travis-ci.org/MarkEdmondson1234/cloudRunner)
[![codecov](https://codecov.io/gh/MarkEdmondson1234/cloudRunner/branch/master/graph/badge.svg)](https://codecov.io/gh/MarkEdmondson1234/cloudRunner)

As easy as possible R scripts in the cloud, via Cloud Run, Cloud Build and Cloud Scheduler.  Continuous Development and Integration tools on Google Cloud Platform.

Not an official Google product.

## Ambition

Point your R code at a function, that automatically deploys and runs it in the GCP cloud via an API endpoint.  As a demo, will deploy R plumber APIs such as demonstrated here: https://github.com/MarkEdmondson1234/cloudRunR

## Install

Only install available from GitHub until depedencies such as `sysreqs` and `containerit` are on CRAN

```r
remotes::install_github("MarkEdmondson1234/googleCloudRunner")
```

## Usage

Please see the [cloudRunner website](https://code.markedmondson.me/cloudRunner/) for topics on how to use:

* [Setup](https://code.markedmondson.me/cloudRunner/articles/setup.html)
* [R APIs using Cloud Run](https://code.markedmondson.me/cloudRunner/articles/cloudrun.html)
* [Serverless R scripts using Cloud Build](https://code.markedmondson.me/cloudRunner/articles/cloudbuild.html)
* [Scheduled R in GCP using Cloud Scheduler](https://code.markedmondson.me/cloudRunner/articles/cloudscheduler.html)
* [Use Cases](https://code.markedmondson.me/cloudRunner/articles/usecases.html)
* [Function Reference](https://code.markedmondson.me/cloudRunner/reference/index.html)

## Author's website blog

See [Mark Edmondson's blog](https://code.markedmondson.me/) that covers examples and code for data science in the Google Cloud Platform

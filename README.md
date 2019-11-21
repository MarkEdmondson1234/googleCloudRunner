# googleCloudRunner

[![Build Status](https://travis-ci.org/MarkEdmondson1234/googleCloudRunner.svg?branch=master)](https://travis-ci.org/MarkEdmondson1234/googleCloudRunner)
[![codecov](https://codecov.io/gh/MarkEdmondson1234/googleCloudRunner/branch/master/graph/badge.svg)](https://codecov.io/gh/MarkEdmondson1234/googleCloudRunner)

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

Browse the [googleCloudRunner website](https://code.markedmondson.me/googleCloudRunner/) for topics on how to use:

* [Setup](https://code.markedmondson.me/googleCloudRunner/articles/setup.html)
* [R APIs using Cloud Run](https://code.markedmondson.me/googleCloudRunner/articles/cloudrun.html)
* [Serverless R scripts using Cloud Build](https://code.markedmondson.me/googleCloudRunner/articles/cloudbuild.html)
* [Scheduled R in GCP using Cloud Scheduler](https://code.markedmondson.me/googleCloudRunner/articles/cloudscheduler.html)
* [Use Cases](https://code.markedmondson.me/googleCloudRunner/articles/usecases.html)
* [Function Reference](https://code.markedmondson.me/googleCloudRunner/reference/index.html)

## Author's website blog

See [Mark Edmondson's blog](https://code.markedmondson.me/) that covers examples and code for data science in the Google Cloud Platform

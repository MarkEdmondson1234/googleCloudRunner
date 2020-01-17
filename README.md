# googleCloudRunner

[![Build Status](https://travis-ci.org/MarkEdmondson1234/googleCloudRunner.svg?branch=master)](https://travis-ci.org/MarkEdmondson1234/googleCloudRunner)
[![codecov](https://codecov.io/gh/MarkEdmondson1234/googleCloudRunner/branch/master/graph/badge.svg)](https://codecov.io/gh/MarkEdmondson1234/googleCloudRunner)
![CRAN](http://www.r-pkg.org/badges/version/googleCloudRunner)

As easy as possible R scripts in the cloud, via Cloud Run, Cloud Build and Cloud Scheduler.  Continuous Development and Integration tools on Google Cloud Platform.

Not an official Google product.

## Ambition

Select an R file, and have it scheduled in the cloud with a couple of clicks.

Deploy your plumber API code automatically on Cloud Run to scale from 0 (no cost) to millions (auto-scaling)

Integrate R inputs and outputs with other languages in a serverless cloud environment.

Have R code react to events such as GitHub pushes, pub/sub messages and Cloud Storage file events. 

## Install

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

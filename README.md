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

Get the CRAN stable version via 

```r
install.packages("googleCloudRunner")
```

Or the development version via:

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

## Resources

Read the blog [introducing the googleCloudRunner package](https://code.markedmondson.me/googleCloudRunner-intro/) that goes into some background.

A talk at R's 20th anniversary was performed at celebRation in Copenhagen on 29th Feb, 2020.  The [slides from the talk are here](https://code.markedmondson.me/r-20.html) and a [video of it is here](https://www.youtube.com/watch?v=YRvejW9FSJ4&list=PLAMHKI_J4xv1urCanNbTCm44CxXnoejdr&index=3):

<iframe width="560" height="315" src="https://www.youtube.com/embed/YRvejW9FSJ4" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

A [googleCloudRunner YouTube playlist](https://www.youtube.com/playlist?list=PLAMHKI_J4xv1urCanNbTCm44CxXnoejdr) of the demos is here.

If you blog anything interesting about the package let me know and I will list it here.

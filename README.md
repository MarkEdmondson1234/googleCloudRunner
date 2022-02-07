# googleCloudRunner

<!-- badges: start -->
![CloudBuild](https://badger-ewjogewawq-ew.a.run.app/build/status?project=mark-edmondson-gde&id=0a3cade0-425f-4adc-b86b-14cde51af674)
[![codecov](https://codecov.io/gh/MarkEdmondson1234/googleCloudRunner/branch/master/graph/badge.svg?token=q2nnGEP8Xi)](https://app.codecov.io/gh/MarkEdmondson1234/googleCloudRunner)
![CRAN](http://www.r-pkg.org/badges/version/googleCloudRunner)
[![CodeFactor](https://www.codefactor.io/repository/github/markedmondson1234/googlecloudrunner/badge/master)](https://www.codefactor.io/repository/github/markedmondson1234/googlecloudrunner/overview/master)
[![R-CMD-check](https://github.com/MarkEdmondson1234/googleCloudRunner/workflows/R-CMD-check/badge.svg)](https://github.com/MarkEdmondson1234/googleCloudRunner/actions)
<!-- badges: end -->

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

The [dev version of the website is here](https://code.markedmondson.me/googleCloudRunner/dev/) which may include documentation of features not yet on CRAN.

## Usage

Browse the [googleCloudRunner website](https://code.markedmondson.me/googleCloudRunner/) for topics on how to use:

* [Setup](https://code.markedmondson.me/googleCloudRunner/articles/setup.html)
* [R APIs using Cloud Run](https://code.markedmondson.me/googleCloudRunner/articles/cloudrun.html)
* [Serverless R scripts using Cloud Build](https://code.markedmondson.me/googleCloudRunner/articles/cloudbuild.html)
* [Scheduled R in GCP using Cloud Scheduler](https://code.markedmondson.me/googleCloudRunner/articles/cloudscheduler.html)
* [Use Cases](https://code.markedmondson.me/googleCloudRunner/articles/usecases.html)
* [Function Reference](https://code.markedmondson.me/googleCloudRunner/reference/index.html)


## Diagrams

Some overviews of the function dependencies are below:

### Scheduling using Cloud Scheduler

![](vignettes/schedule_plot.png)

### Building using Cloud Build

![](vignettes/build_plot.png)

### Helper deployment functions calling lower-level functions

![](vignettes/deploy_plot.png)

### Cloud Run functionality

![](vignettes/cloudrun_plot.png)

### library(targets) integration functions

![](vignettes/targets_plot.png)

## Sponsor

<iframe src="https://github.com/sponsors/MarkEdmondson1234/card" title="Sponsor MarkEdmondson1234" height="225" width="600" style="border: 0;"></iframe>

## Resources

Read the blog [introducing the googleCloudRunner package](https://code.markedmondson.me/googleCloudRunner-intro/) that goes into some background.

A talk at R's 20th anniversary was performed at celebRation in Copenhagen on 29th Feb, 2020.  The [slides from the talk are here](https://code.markedmondson.me/r-20.html) and a [video of it is here](https://www.youtube.com/watch?v=YRvejW9FSJ4&list=PLAMHKI_J4xv1urCanNbTCm44CxXnoejdr&index=3):

<iframe width="560" height="315" src="https://www.youtube.com/embed/YRvejW9FSJ4" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

A [googleCloudRunner YouTube playlist](https://www.youtube.com/playlist?list=PLAMHKI_J4xv1urCanNbTCm44CxXnoejdr) of the demos is here.

If you blog anything interesting about the package let me know and I will list it here.

* Ander has a guide on using googleCloudRunner to [schedule an R script on GCP](https://anderfernandez.com/blog/automatizar-script-r-google-cloud/) [Spanish]
* Ander also writes how to use googleCloudRunner to [productionise your R plumber API](https://anderfernandez.com/blog/como-poner-en-produccion-un-modelo-de-machine-learning-de-r/) [Spanish]
* Arben documents his experience on how he got started [scheduling BigQuery uploads using Docker and R](https://arbenkqiku.github.io/create-docker-image-with-r-and-deploy-as-cron-job-on-google-cloud)
* Michał Ludwicki was a huge help in mentoring Arben for the post above - he also has created a GitHub repo of some [useful example files for googleCloudRunner scripts](https://github.com/MLud/GCP_Rscheduler)
* Sam Terfa has a guide on how to use googleCloudRunner to [create an R API you can use GoogleSheets](https://towardsdatascience.com/using-r-and-python-in-google-sheets-formulas-b397b302098) to create its front end 
* Louis shows how to [create and deploy your own Python optimisation API using googleCloudRunner](https://louis-boguchwal.medium.com/create-and-deploy-your-own-optimization-api-7b4275f159c9)


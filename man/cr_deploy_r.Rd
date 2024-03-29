% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/deploy.R
\name{cr_deploy_r}
\alias{cr_deploy_r}
\title{Deploy an R script with an optional schedule}
\usage{
cr_deploy_r(
  r,
  schedule = NULL,
  source = NULL,
  run_name = NULL,
  r_image = "rocker/verse",
  pre_steps = NULL,
  post_steps = NULL,
  timeout = 600L,
  ...,
  schedule_type = c("pubsub", "http"),
  schedule_pubsub = NULL,
  email = cr_email_get(),
  region = cr_region_get(),
  projectId = cr_project_get(),
  serviceAccount = NULL,
  launch_browser = interactive()
)
}
\arguments{
\item{r}{R code to run or a file containing R code ending with .R, or the gs:// location on Cloud Storage of the R file you want to run}

\item{schedule}{A cron schedule e.g. \code{"15 5 * * *"}}

\item{source}{A \link{Source} object specifying the location of the source files to build, usually created by \link{cr_build_source}}

\item{run_name}{What name the R code will identify itself as.  If \code{NULL} one is autogenerated.}

\item{r_image}{The R docker environment executing the R code}

\item{pre_steps}{Other \link{cr_buildstep} to run before the R code executes}

\item{post_steps}{Other \link{cr_buildstep} to run after the R code executes}

\item{timeout}{Amount of time that this build should be allowed to run, to second}

\item{...}{
  Arguments passed on to \code{\link[=cr_buildstep_r]{cr_buildstep_r}}
  \describe{
    \item{\code{name}}{The docker image that will run the R code, usually from rocker-project.org}
    \item{\code{r_source}}{Whether the R code will be from a runtime file within the source or at build time copying over from a local R file in your session}
    \item{\code{escape_dollar}}{Default TRUE.  This will turn \code{$} into \code{$$} within the script to avoid them being recognised as Cloud Build variables.  Turn this off if you want that behaviour (e.g. \code{my_project="$PROJECT_ID"})}
    \item{\code{rscript_args}}{Optional arguments for the R script run by \code{Rscript}.}
    \item{\code{r_cmd}}{should `Rscript` be run or `R`?}
    \item{\code{prefix}}{prefixed to name - set to "" to suppress.  Will be suppressed if \code{name} starts with gcr.io or \code{*-docker.pkg.dev}}
  }}

\item{schedule_type}{If you have specified a schedule, this will select what strategy it will use to deploy it. See details}

\item{schedule_pubsub}{If you have a custom pubsub message to send via an existing topic, use \link{cr_schedule_pubsub} to supply it here}

\item{email}{The email that will authenticate the job set via \link{cr_email_set}}

\item{region}{The region usually set with \link{cr_region_set}}

\item{projectId}{ID of the project}

\item{serviceAccount}{service account email to be used for the build}

\item{launch_browser}{Whether to launch the logs URL in a browser once deployed}
}
\value{
If scheduling then a \link{Job}, if building immediately then a \link{Build}
}
\description{
Will create a build to run an R script in Cloud Build with an optional schedule from Cloud Scheduler
}
\details{
The R script will execute within the root directory of whichever \link{Source} you supply, usually created via \link{cr_build_source} representing a Cloud Storage bucket or a GitHub repository that is copied across before code execution.  Bear in mind if the source changes then the code scheduled may need updating.

The \code{r_image} dictates what R libraries the R environment executing the code of \code{r} will have, via the underlying Docker container usually supplied by rocker-project.org.  If you want custom R libraries beyond the default, create a docker container with those R libraries installed (perhaps via \link{cr_deploy_docker})
}
\section{Scheduling}{


If \code{schedule=NULL} then the R script will be run immediately on Cloud Build via \link{cr_build}.

If \code{schedule} carries a cron job string (e.g. \code{"15 5 * * *"}) then the build will be scheduled via Cloud Scheduler

If \code{schedule_type="pubsub"} then you will need \code{googlePubsubR} installed and set-up and scheduling will involve:

\enumerate{
  \item Creating a PubSub topic called \code{"{run_name}-topic"} or subscribing to the one you provided in \code{schedule_pubsub}.  It is assumed you have created the PubSub topic beforehand if you do supply your own.
  \item Create a Build Trigger called \code{"{run_name}-trigger"} that will run when the PubSub topic is called
  \item Create a Cloud Schedule called \code{"{run_name}-trigger"} that will send a pubsub message to the topic: either the default that contains just the name of the script, or the message you supplied in \code{schedule_pubsub}.
 }

Type "pubsub" is recommended for more complex R scripts as you will have more visibility for debugging schedules via inspecting the PubSub topic, build trigger and build logs, as well as enabling triggering the script from other PubSub topics and allowing to pass dynamic parameters into your schedule scripts via the PubSub message.

If \code{schedule_type="http"} then scheduling will involve:

\enumerate{
  \item Create a Cloud Build API call with your build embedded within it via \link{cr_schedule_http}
  \item Schedule the HTTP call using the authentication email supplied in \code{email} or the default \link{cr_email_get}
 }

This is the old default and is suitable for smaller R scripts or when you don't want to use the other  GCP services.  The authentication for the API call from Cloud Scheduler can cause opaque errors as it will give you invalid response codes whether its that or an error in your R script you wish to schedule.
}

\examples{

r_lines <- c(
  "list.files()",
  "library(dplyr)",
  "mtcars \%>\% select(mpg)",
  "sessionInfo()"
)
source <- cr_build_source(RepoSource("googleCloudStorageR",
  branchName = "master"
))
\dontrun{
cr_project_set("my-project")
cr_region_set("europe-west1")
cr_email_set("123456@projectid.iam.gserviceaccount.com")

# check the script runs ok
cr_deploy_r(r_lines, source = source)

# schedule the script
cr_deploy_r(r_lines, schedule = "15 21 * * *", source = source)
}

}
\seealso{
If you want to run R code upon certain events like GitHub pushes, look at \link{cr_buildtrigger}

Other Deployment functions: 
\code{\link{cr_deploy_docker_trigger}()},
\code{\link{cr_deploy_docker}()},
\code{\link{cr_deploy_packagetests}()},
\code{\link{cr_deploy_pkgdown}()},
\code{\link{cr_deploy_run_website}()},
\code{\link{cr_deploy_run}()}
}
\concept{Deployment functions}

% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/build_logs.R
\name{cr_build_logs}
\alias{cr_build_logs}
\alias{cr_buildtrigger_logs}
\title{Download logs from a Cloud Build}
\usage{
cr_build_logs(built = NULL, log_url = NULL)

cr_buildtrigger_logs(
  trigger_name = NULL,
  trigger_id = NULL,
  projectId = cr_project_get()
)
}
\arguments{
\item{built}{The built object from \link{cr_build_status} or \link{cr_build_wait}}

\item{log_url}{You can optionally instead of \code{built} provide the direct gs:// URI to the log here.  It is in the format \code{gs://{{bucket}}/log-{{buildId}}.txt}}

\item{trigger_name}{The trigger name to check, will be used to look up trigger_id}

\item{trigger_id}{If supplied, trigger_name will be ignored}

\item{projectId}{The project containing the trigger_id}
}
\description{
This lets you download the logs to your local R session, rather than viewing them in the Cloud Console.
}
\details{
By default, Cloud Build stores your build logs in a Google-created Cloud Storage bucket. You can view build logs store in the Google-created Cloud Storage bucket, but you cannot make any other changes to it. If you require full control over your logs bucket, store the logs in a user-created Cloud Storage bucket.
}
\examples{
\dontrun{
s_yaml <- cr_build_yaml(steps = cr_buildstep("gcloud", "version"))
build <- cr_build_make(s_yaml)
built <- cr_build(build)
the_build <- cr_build_wait(built)
cr_build_logs(the_build)
# [1] "starting build \"6ce86e05-b0b1-4070-a849-05ec9020fd3b\""
# [2] ""
# [3] "FETCHSOURCE"
# [4] "BUILD"
# [5] "Already have image (with digest): gcr.io/cloud-builders/gcloud"
# [6] "Google Cloud SDK 325.0.0"
# [7] "alpha 2021.01.22"
# [8] "app-engine-go 1.9.71"
# ...
}
\dontrun{

# get your trigger name
ts <- cr_buildtrigger_list()
ts$buildTriggerName

my_trigger <- "package-checks"
last_logs <- cr_buildtrigger_logs(my_trigger)

my_trigger_id <- "0a3cade0-425f-4adc-b86b-14cde51af674"
last_logs <- cr_buildtrigger_logs(trigger_id = my_trigger_id)
}
}
\seealso{
\url{https://cloud.google.com/build/docs/securing-builds/store-manage-build-logs}

\link{cr_build_logs_badger} to see logs for a badger created build

Other Cloud Build functions: 
\code{\link{Build}()},
\code{\link{RepoSource}()},
\code{\link{Source}()},
\code{\link{StorageSource}()},
\code{\link{cr_build_artifacts}()},
\code{\link{cr_build_list}()},
\code{\link{cr_build_make}()},
\code{\link{cr_build_status}()},
\code{\link{cr_build_targets}()},
\code{\link{cr_build_upload_gcs}()},
\code{\link{cr_build_wait}()},
\code{\link{cr_build_write}()},
\code{\link{cr_build_yaml_artifact}()},
\code{\link{cr_build_yaml_secrets}()},
\code{\link{cr_build_yaml}()},
\code{\link{cr_build}()}
}
\concept{Cloud Build functions}

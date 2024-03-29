% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/buildsteps_templates.R
\name{cr_buildstep_bash}
\alias{cr_buildstep_bash}
\title{Run a bash script in a Cloud Build step}
\usage{
cr_buildstep_bash(
  bash_script,
  name = "ubuntu",
  bash_source = c("local", "runtime"),
  escape_dollar = TRUE,
  ...
)
}
\arguments{
\item{bash_script}{bash code to run or a filepath to a file containing bash code that ends with .bash or .sh}

\item{name}{The image that will run the R code}

\item{bash_source}{Whether the code will be from a runtime file within the source or at build time copying over from a local file in your session}

\item{escape_dollar}{Default TRUE.  This will turn \code{$} into \code{$$} within the script to avoid them being recognised as Cloud Build variables.  Turn this off if you want that behaviour (e.g. \code{my_project="$PROJECT_ID"})}

\item{...}{Other arguments passed to \link{cr_buildstep}}
}
\description{
Helper to run a supplied bash script, that will be copied in-line
}
\details{
If you need to escape build parameters in bash scripts, you need to escape CloudBuild's substitution via \code{$$} and bash's substitution via \code{\$} e.g. \code{\$$PARAM}
}
\examples{
cr_project_set("my-project")
bs <- cr_build_yaml(
  steps = cr_buildstep_bash("echo 'Hello'")
)
\dontrun{
cr_build(bs)
}
}
\seealso{
Other Cloud Buildsteps: 
\code{\link{cr_buildstep_decrypt}()},
\code{\link{cr_buildstep_df}()},
\code{\link{cr_buildstep_docker}()},
\code{\link{cr_buildstep_edit}()},
\code{\link{cr_buildstep_extract}()},
\code{\link{cr_buildstep_gcloud}()},
\code{\link{cr_buildstep_gitsetup}()},
\code{\link{cr_buildstep_mailgun}()},
\code{\link{cr_buildstep_nginx_setup}()},
\code{\link{cr_buildstep_packagetests}()},
\code{\link{cr_buildstep_pkgdown}()},
\code{\link{cr_buildstep_run}()},
\code{\link{cr_buildstep_r}()},
\code{\link{cr_buildstep_secret}()},
\code{\link{cr_buildstep_slack}()},
\code{\link{cr_buildstep_targets}()},
\code{\link{cr_buildstep}()}
}
\concept{Cloud Buildsteps}

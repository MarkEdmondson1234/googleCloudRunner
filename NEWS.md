# googleCloudRunner 0.5.0.9000

* Added `full` flag argument to `cr_buildtrigger_list` to return a column `build`, which is a list of the builds.

# googleCloudRunner 0.5.0

* Add checks for Cloud Build email roles in `cr_setup()`
* Add direct Secret Manager environment args in builds via `availableSecrets` (#106)
* Add support for `logsBucket` in `cr_build_yaml` and `cr_build_make`
* Add `cr_build_list()` and `cr_build_list_filter()` 
* Add `cr_build_logs()` and `cr_buildtrigger_logs()` and `cr_build_logs_badger()`
* Made Cloud Build status messages prettier
* Add messaging to `cr_build_upload_gcs()` saying where deploy folder is (#110) and clean up tar.gz folder correctly
* Add `gcloud_args` to `cr_buildstep_run()` and `cr_run()` and `cr_deploy_run()` to allow more customisation (#113)
* Add `cr_run_schedule_http()` to schedule Cloud Run HTTP calls (#113)
* Allow usage of `cr_build_yaml()` objects directly in `cr_buildtrigger()` without needing `cr_build_make()`
* Fix `cr_deploy_pkgdown()` error writing to file
* Allow `escape_dollar` in `cr_buildstep_r()` and `cr_buildstep_bash()` if you want to use Cloud Build substitutions in the script (#104)
* Allow direct support for Codecov (#116)
* Parse `gar_Build` objects to lists in buildtrigger responses so they can be more easily reused
* Fix bug with Cloud Run deployments not returning image names (#141 - thanks @engti)
* Added rscript_args to `cr_buildstep_r()` - (#128 - thanks @simonsays1980)
* All `cr_setup_test()` to be run without the interactive menu (#129 - thanks @muschellij2)
* Add `cr_regions` data that lists available Cloud Run regions (thanks @muschellij2)
* Allow specification of a target GCP project if it differs from the build project in `cr_deploy_docker_trigger()`
* Force lowercase for docker image names as they are only valid for kaniko in `cr_deploy_docker_trigger()`
* Fix bug parsing out listing build triggers in `cr_buildtrigger_list()`
* Fix paging issue sometimes returning NULL for `cr_build_list()` (#149)
* Update `cr_deploy_r()` to use PubSub/BuildTrigger as its default when scheduling (#148)
* Add support for running `targets::tar_make()` pipelines on Cloud Build via `cr_build_targets()` (#155)
* Rename `cr_build_schedule_http()` to `cr_schedule_http()` to be more in line with `cr_schedule_pubsub()` and `cr_schedule_build()`

# googleCloudRunner 0.4.1

* Fix faulty test for `cr_setup_tests()` that was failing option 3 (#104)
* Fix R and bash scripts failing builds and schedules if they included a `$` character in the script (#103 - thanks @yfarjoun)
* Fix `cr_setup_auth()` not being called in `cr_setup()`

# googleCloudRunner 0.4.0

* Remove checking for existence of cloudscheduler.serviceAgent (#89 - thanks @BillPetti)
* Setting env vars for Cloud Run runtime deployments fixed 
* Added `cr_jwt_create()` and family to create JWTs to call authenticated services such as Cloud Run (#91)
* Add authenticated Cloud Run use case
* Ensure timeout is under 86400 secs (24hrs) in `cr_build_make()`
* Add `cr_buildtrigger_copy()`
* Extra checks for existence of valid auth file when creating build email (#89)
* We can't check for existence of cloud build email #94 so `cr_setup()` will only set roles in assumed present Google service emails.
* Include `plumber` in Depends as its needed for most applications - makes `FROM gcr.io/gcer-public/googlecloudrunner:master` more useful in Docker files.
* Update example plumber deployment to use Rscript to start plumber server (#97)
* Add R to git use case example
* Improve `cr_setup()` for buckets

# googleCloudRunner 0.3.0

* Move the setup wizard functions from `googleCloudRunner` to `googleAuthR` so they are available for all packages.
* Check for Cloud Scheduler Service Agent is present for scheduler to work (#73)
* `cr_build_upload_gcs()` will now clean up the files it makes when the function exits (#68 - thanks @MLud)
* Support local testing in plumber example (#66 - thanks @samterfa)
* Support multiple tags in Docker builds (#75)
* Fix being able to pass built Cloud Build objects to schedule via `cr_build_schedule_http()` (#47)
* Add progress for Cloud builds via library(progress) (#29)
* Add support for Kaniko cache in `cr_buildstep_docker()` and `cr_deploy_docker()` (#46) -should see much quicker repeat builds
* Let use of bucket level access control when using `cr_deploy_docker()`
* Added support for creating buildtriggers from R (#78)
* `cr_deploy_pkgdown()`, `cr_deploy_docker_trigger()` and `cr_deploy_packagetests()` now all have an option to create the build trigger for you
* Add `cr_deploy_badger()` for creating build badges with Cloud Build via https://github.com/kelseyhightower/badger (#15)
* Add `cr_deploy_run_website()` for rendering Rmd files then hosting on an nginx Cloud Run
* The packagetools docker updates weekly `gcr.io/gcer-public/packagetools:latest` (#55)
* Fix `cr_schedule()` crash of `overwrite=TRUE` but no existing schedule
* Add deploy Shiny to k8s and Cloud Run example use cases
* Allow max_instances in `cr_run` so it can run Shiny apps (#35)
* Add `cr_buildstep_gcloud()` for optimum gcloud builds (#83)

# googleCloudRunner 0.2.0

* Add `port` argument to Cloud Run deployments via `cr_buildstep_run()`
* Add `cr_deploy_pkgdown` and `cr_deploy_packagetests` add subsequent buildsteps to aid R package development.
* Fix `cr_buildstep_r()` so it can run R scripts from a filename when `r_source="runtime"` (#45 - thanks @j450h1 and @axel-analyst)
* Add ability to run R scripts straight from Cloud Storage (#45 - thanks @j450h1 and @axel-analyst) - specify R script location starting with `gs://`
* Let `timeout` be specified within `cr_build_yaml()` (#43 - thanks @dmoimpact)
* Correct print method for build substitutions
* Update `cr_schedule_list()` to only return non-nested data
* Allow specification of Dockerfile name in `cr_buildstep_docker()`
* Easier parsing of env arguments in `cr_buildstep()`
* Entrypoint in `cr_buildstep()` accepts one argument only
* Allow specification of timezone in `cr_schedule()` (#49 - thanks @samterfa)
* Let `cr_deploy_r()` pass through arguments to `cr_buildstep_r()` (#50 - thanks @samterfa)
* Modify `cr_deploy_packagetests()` so it can pass through dot arguments to `cr_build_yaml()` such as `timeout`
* Add `cr_buildstep_secret()` using Secret Manager (#52)
* Update `cr_deploy_pkgdown()` to use Secret Manager (#54)
* Remove unnecessary `projectId` argument from `cr_build_make()` (#57)
* Add `cr_setup()` to help setup a googleCloudRunner environment (#53)

# googleCloudRunner 0.1.1

* Initial release

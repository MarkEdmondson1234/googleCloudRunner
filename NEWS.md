# googleCloudRunner 0.1.1.9000

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

# googleCloudRunner 0.1.1

* Initial release

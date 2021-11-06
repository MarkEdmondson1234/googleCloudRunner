#' Buildstep to deploy to Google Compute Engine
#'
#' This build step adds some helpers to \link{cr_buildstep_gcloud} for deploying to VMs to GCE
#'
#' @export
cr_buildstep_compute_rstudio <- function(
  rstudio_user,
  rstudio_pw,
  vm_name = "rstudio",
  template = "gcr.io/gcer-public/persistent-rstudio",
  disk_name = "rstudio-disk", # do check to see if it exists, if it does attach
  disk_size = "10GB",
  machine_type = "n1-standard-1"
){

  # https://cloud.google.com/compute/docs/containers/deploying-containers
  # https://cloud.google.com/sdk/gcloud/reference/compute/instances/create-with-container
  cr_buildstep_gcloud(
    "gcloud",
    args = c(
      "compute",
      "instances",
      "create-with-container",
      vm_name,
      sprintf("--container-env=[ROOT=TRUE,USER=%s,PASSWORD=%s]",
              rstudio_user, rstudio_pw),
      sprintf("--container-image %s", template),
      sprintf("--container-mount-disk=name=%s,mount-path=/home/%s",
              disk_name, rstudio_user),
      sprintf("--create-disk=name=%s,size=%s", disk_name, disk_size),
      sprintf("--machine-type=%s", machine_type),
      sprintf("--scopes=cloud-platform")
    )

  )

}

#' Buildstep to deploy to Google Compute Engine
#'
#' This build step adds some helpers to \link{cr_buildstep_gcloud} for deploying to VMs to GCE that will auto create a container within them and atytach it to the disk
#'
#' @export
#' @examples
#'
#' bs <- cr_buildstep_compute_rstudio("mark", "securepassword1234")
#' build <- cr_build_yaml(bs)
#' build
#' \dontrun{
#'
#' cr_build(build)
#' }
#' @param vm_name Name of the VM you will create
#' @param disk_name Name of the disk that will be attached to the VM's container image
#' @param disk_mount_path Where the disk will be attached to the container in the VM
#' @param container_image The Docker image that will be launched in the VM
#' @param zone Which zone the VM will launch within
#' @param disk_size The size of the disk
#' @param machine_type The type of VM that will be launched
#' @param container_env Environment variables set within the VM's container image
#' @param scopes The GCE scopes that the VM will be launched with permission to use
#' @param network The network the VM will use.  The container will bridge into the same network
#' @param gcloud_args Other gcloud arguments you send in e.g. \code{c("--boot-disk-device-name=boot-disk1","--boot-disk-size=10GB")}
cr_buildstep_compute_container <- function(vm_name,
                                           container_image = "gcr.io/gcer-public/persistent-rstudio:latest",
                                           disk_name = paste0(vm_name, "-disk"), # do check to see if it exists, if it does attach
                                           disk_mount_path = "/home",
                                           zone = "europe-west1-b",
                                           disk_size = "10GB",
                                           machine_type = "n1-standard-1",
                                           container_env = "",
                                           scopes = "cloud-platform",
                                           network = "default",
                                           gcloud_args = NULL) {

  # https://cloud.google.com/compute/docs/containers/deploying-containers
  # https://cloud.google.com/sdk/gcloud/reference/compute/instances/create-with-container
  cr_buildstep_gcloud(
    args = c(
      "gcloud",
      "compute",
      "instances",
      "create-with-container",
      vm_name,
      sprintf("--container-env=%s", container_env),
      sprintf("--container-image=%s", container_image),
      sprintf(
        "--container-mount-disk=name=%s,mount-path=%s",
        disk_name, disk_mount_path
      ),
      sprintf("--create-disk=name=%s,size=%s", disk_name, disk_size),
      sprintf("--machine-type=%s", machine_type),
      sprintf("--scopes=%s", scopes),
      sprintf("--zone=%s", zone),
      sprintf("--network=%s", network),
      gcloud_args
    )
  )
}

#' @rdname cr_buildstep_compute_container
#' @param rstudio_user The usename for the RStudio image the VM will launch
#' @param rstudio_pw The password for the RStudio image the VM will launch
#' @export
cr_buildstep_compute_rstudio <- function(rstudio_user,
                                         rstudio_pw,
                                         vm_name = "rstudio",
                                         disk_name = "rstudio-disk", # do check to see if it exists, if it does attach
                                         zone = "europe-west1-b",
                                         disk_size = "10GB",
                                         machine_type = "n1-standard-1",
                                         container_image = "gcr.io/gcer-public/persistent-rstudio:latest",
                                         network = "default") {

  # https://cloud.google.com/compute/docs/containers/deploying-containers
  # https://cloud.google.com/sdk/gcloud/reference/compute/instances/create-with-container
  cr_buildstep_compute_container(
    vm_name,
    disk_name = disk_name,
    disk_mount_path = sprintf("/home/%s", rstudio_user),
    zone = zone,
    disk_size = disk_size,
    machine_type = machine_type,
    container_image = container_image,
    container_env = sprintf(
      "--container-env=[ROOT=TRUE,USER=%s,PASSWORD=%s]",
      rstudio_user, rstudio_pw
    ),
    scopes = "cloud-platform",
    network = network # not the same as firewall
  )
}

#' Deploy Compute Engine running RStudio

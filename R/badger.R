#' Deploy a Cloud Run app to display build badges
#'
#' This uses \url{https://github.com/kelseyhightower/badger} to create badges you can display in README.md etc. showing the current status of a Cloud Build
#'
#' @param json The clientId JSON file of the project to create within
#' @param badger_image The docker image from the badger project to use
#' @param region The Cloud Run region
#'
#' @export
cr_deploy_badger <- function(badger_image = "gcr.io/hightowerlabs/badger:0.0.1",
                             json = Sys.getenv("GAR_CLIENT_JSON"),
                             region = cr_region_get()){

  myMessage("#Deploying a badger instance on Cloud Run", level = 3)
  myMessage("Authenticate the service key that badger will use to check Cloud Build status:", level = 3)

  projectId <- gar_set_client(json,
                              scopes = "https://www.googleapis.com/auth/cloud-platform")
  gar_auth(cache = FALSE)

  created<- gar_service_create("badger", projectId = projectId,
                     serviceDescription = "Enables build badges for Cloud Build")

  gar_service_grant_roles(created$email,
                          roles = "roles/cloudbuild.builds.viewer",
                          projectId = projectId)

  bs <- c(
    cr_buildstep("gcloud",
                 args = c("run","deploy", "badger",
                   "--allow-unauthenticated",
                   "--service-account", "badger@$PROJECT_ID.iam.gserviceaccount.com",
                   "--concurrency","80",
                   "--cpu", "1",
                   "--image", badger_image,
                   "--memory","128Mi",
                   "--platform","managed",
                   "--region", region),
                 id = "deploy badger on cloudrun")
  )

  build_yaml <- cr_build_yaml(bs)
  build <- cr_build(build_yaml)

  result <- cr_build_wait(build, projectId = projectId)

  if(result$status != "SUCCESS"){
    myMessage("#Problem deploying to Cloud Run", level = 3)
    return(result)
  }

  run <- cr_run_get("badger", projectId = projectId)
  myMessage(paste("#> Running at: ",
                  run$status$url), level = 3)

  print(run)

  myMessage("Buildtriggers via cr_buildtrigger_list()", level =3)
  bts <- cr_buildtrigger_list()
  print(bts[, c('id','name','description')])

  myMessage("Use in README.md files etc. via below markdown below:", level =3)
  myMessage(sprintf("![CloudBuild](%s/build/status?project=%s&id={your-trigger-id})",
                    run$status$url, projectId), level = 3)
}

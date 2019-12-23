#' Deploy Docker build from a GitHub repo
#'
#' This helps the common use case of building a Dockerfile based on the contents of a GitHub repo, and sets up a build trigger so it will build on every commit.
#'
#' @seealso \link{cr_deploy_docker} which lets you build Dockerfiles for more generic use cases
#'
#' @param x The GitHub repo e.g. \code{MarkEdmondson1234/googleCloudRunner}
#' @param image The name of the image you want to build
#' @param branch A regex of the GitHub branches that will trigger a build
#' @param image_tag What to tag the build docker image
#' @param dockerfile_location Where the Dockerfile sits within the GitHub repo
#' @param github_tag Regexes matching what tags to build. If not NULL then argument branch will be ignored
#' @param projectId The project to build under
#' @param timeout timeout for the Docker build
#' @family Deployment functions
#' @export
cr_deploy_github_docker <- function(x,
                                    image = x,
                                    branch = ".*",
                                    image_tag = "$SHORT_SHA",
                                    dockerfile_location = ".",
                                    github_tag = NULL,
                                    timeout = 600L,
                                    projectId = cr_project_get()){

  build_docker <- cr_build_make(
    cr_build_yaml(
      steps = cr_buildstep_docker(image,
                                  tag = image_tag,
                                  location = dockerfile_location),
      images = paste0("gcr.io/", projectId, "/", image),
      timeout = timeout
    ))

  github <- GitHubEventsConfig(x, branch = branch, tag = github_tag)

  safe_name <- gsub("[^a-zA-Z1-9]","-", x)
  cr_buildtrigger(safe_name,
                  description = safe_name,
                  trigger = github,
                  build = build_docker)
}

#' Deploy HTML built from a GitHub repo each commit
#'
#' This lets you set up triggers that will update a website each commit
#'
#' @seealso \link{cr_deploy_html} that lets you deploy HTML files
#'
#' @param rmd_folder A folder of Rmd files within GitHub source that will be built into HTML for serving via \link[rmarkdown]{render}
#' @param html_folder A folder of html to deploy within GitHub source.  Will be ignored if rmd_folder is not NULL
#' @param edit_r If you want to change the R code to render the HTML, supply R code via a file or string of R as per \link{cr_buildstep_r}
#' @param region The region for cloud run
#' @inheritParams cr_deploy_github_docker
#' @family Deployment functions
#'
#' @details
#'
#' This default R code is rendered in the rmd_folder:
#'
#' \code{lapply(list.files('.', pattern = '.Rmd', full.names = TRUE),
#'       rmarkdown::render, output_format = 'html_document')}
#'
#' You need to mirror the repo onto Google Cloud Repositories, as well as connect to the GitHub app for the source and the build trigger to work from the same GitHub repo.
#'
#' @export
#' @examples
#'
#' \dontrun{
#'   cr_deploy_github_html("MarkEdmondson1234/googleCloudRunner",
#'                         rmd_folder = "vignettes")
#' }
cr_deploy_github_html <- function(x,
                                  image = paste0(x,"-html"),
                                  rmd_folder = NULL,
                                  html_folder = NULL,
                                  branch = ".*",
                                  image_tag = "$SHORT_SHA",
                                  github_tag = NULL,
                                  timeout = 600L,
                                  edit_r = NULL,
                                  region = cr_region_get(),
                                  projectId = cr_project_get()){

  assert_that(
    xor(!is.null(rmd_folder), !is.null(html_folder))
  )

  r <- "lapply(list.files('.', pattern = '.Rmd', full.names = TRUE),
       rmarkdown::render, output_format = 'html_document')"
  if(!is.null(edit_r)){
    r <- edit_r
  }

  rmd_step <- NULL
  if(!is.null(rmd_folder)){
    rmd_step <- cr_buildstep_r(r, dir = rmd_folder, id="render rmd")
    html_folder <- rmd_folder
    glob <- paste0(rmd_folder,"/**")
  } else {
    glob <- paste0(html_folder,"/**")
  }

  bash_script <- system.file("docker", "nginx", "setup.bash",
                             package = "googleCloudRunner")

  build_html <- cr_build_make(
    cr_build_yaml(
      steps = c(
          rmd_step,
          cr_buildstep_bash(bash_script,
                            dir = html_folder, id = "setup nginx"),
          cr_buildstep_docker(image,tag = image_tag, dir = html_folder),
          cr_buildstep("gcloud",
                       c("beta","run","deploy", image,
                         "--image", image,
                         "--region", region,
                         "--platform", "managed",
                         "--concurrency", 80
                       ),
                       id = "deploy cloudrun")
          )
    ),
    images = paste0("gcr.io/", projectId, "/", image),
    timeout = timeout,
    options = list(substitution_option = "ALLOW_LOOSE"),
    source = cr_build_source(RepoSource(make_github_mirror(x),
                                        tagName = github_tag,
                                        branchName = branch,
                                        projectId = projectId))
    )

  github <- GitHubEventsConfig(x, branch = branch, tag = github_tag)

  safe_name <- gsub("[^a-zA-Z1-9]","-", x)
  cr_buildtrigger(safe_name,
                  description = safe_name,
                  trigger = github,
                  build = build_html,
                  substitutions = list(`_PORT` = "${PORT}"),
                  includedFiles = glob)


}


make_github_mirror <- function(x){
  paste0("github_", tolower(gsub("/","_", x)))
}

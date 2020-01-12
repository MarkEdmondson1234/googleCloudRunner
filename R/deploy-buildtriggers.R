#' Deploy Docker build from a GitHub repo (Experimental)
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
#' @details
#'
#' Build trigger API is experimental so this function is in development.
#'
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

#' Deploy HTML built from a repo each commit (Experimental)
#'
#' This lets you set up triggers that will update a website each commit. You need to mirror the GitHub/Bitbucket repo onto Google Cloud Repositories for this to work.
#'
#' @seealso \link{cr_deploy_html} that lets you deploy HTML files
#'
#' @param rmd_folder A folder of Rmd files within GitHub source that will be built into HTML for serving via \link[rmarkdown]{render}
#' @param html_folder A folder of html to deploy within GitHub source.  Will be ignored if rmd_folder is not NULL
#' @param edit_r If you want to change the R code to render the HTML, supply R code via a file or string of R as per \link{cr_buildstep_r}
#' @param region The region for cloud run
#' @param r_image The image that will run the R code from \code{edit_r}
#' @inheritParams cr_deploy_github_docker
#' @inheritParams cr_buildstep_run
#' @family Deployment functions
#'
#' @details
#'
#' Build trigger API is experimental so this function is in development.
#'
#' This default R code is rendered in the rmd_folder:
#'
#' \code{lapply(list.files('.', pattern = '.Rmd', full.names = TRUE),
#'       rmarkdown::render, output_format = 'html_document')}
#'
#' You need to mirror the GitHub/Bitbucket repo onto Google Cloud Repositories for this to work
#'
#' @export
#' @examples
#'
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' your_repo <- "MarkEdmondson1234/googleCloudRunner"
#' cr_deploy_git_html(your_repo, rmd_folder = "vignettes")
#'
#' # change the Rmd rendering to pkgdown
#' r <- "devtools::install();pkgdown::build_site()"
#'
#' cr_deploy_git_html(your_repo,
#'                    image = paste0(your_repo, "-pkgdown"),
#'                    rmd_folder = ".",
#'                    edit_r = r)
#'
#' }
cr_deploy_git_html <- function(x,
                               image = paste0(x,"-html"),
                               rmd_folder = NULL,
                               html_folder = NULL,
                               branch = ".*",
                               image_tag = "$SHORT_SHA",
                               github_tag = NULL,
                               timeout = 600L,
                               edit_r = NULL,
                               r_image = "gcr.io/gcer-public/packagetools:master",
                               allowUnauthenticated = TRUE,
                               region = cr_region_get(),
                               projectId = cr_project_get()){

  assert_that(
    xor(!is.null(rmd_folder), !is.null(html_folder))
  )

  image <- gsub("[^-a-zA-Z0-9\\/]","",tolower(image))

  r <- "lapply(list.files('.', pattern = '.Rmd', full.names = TRUE),
       rmarkdown::render, output_format = 'html_document')"
  if(!is.null(edit_r)){
    r <- edit_r
  }

  glob_f <- function(x){
    if(x=="."){
      return(x)
    }
    paste0(x,"/**")
  }

  rmd_step <- NULL
  if(!is.null(rmd_folder)){
    rmd_step <- cr_buildstep_r(r,
                  name = r_image,
                  dir = rmd_folder,
                  id="render rmd")
    html_folder <- rmd_folder
    glob <- glob_f(rmd_folder)
  } else {
    glob <- glob_f(html_folder)
  }

  repo_source <- RepoSource(make_github_mirror(x),
                            tagName = github_tag,
                            branchName = branch,
                            projectId = projectId)

  cr_image <- lower_alpha_dash(image)
  run_image <- sprintf("%s:%s", make_image_name(image, projectId), image_tag)

  build_html <- cr_build_make(
    cr_build_yaml(
      steps = c(
          rmd_step,
          cr_buildstep_nginx_setup(html_folder),
          cr_buildstep_docker(image,
                              tag = image_tag,
                              dir = html_folder,
                              projectId = projectId),
          cr_buildstep_run(name = cr_image,
                           image = run_image,
                           allowUnauthenticated = allowUnauthenticated,
                           region = region,
                           concurrency = 80)
          )
    ),
    images = run_image,
    timeout = timeout,
    source = cr_build_source(repo_source)
    )

  safe_name <- gsub("[^a-zA-Z1-9]","-", image)
  cr_buildtrigger(safe_name,
                  description = safe_name,
                  trigger = repo_source,
                  build = build_html,
                  includedFiles = glob)


}


make_github_mirror <- function(x){
  paste0("github_", tolower(gsub("/","_", x)))
}

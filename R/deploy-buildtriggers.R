
#' Deploy HTML built from a repo each commit
#'
#' This lets you set up triggers that will update an R generated website each commit.
#'
#' @seealso \link{cr_deploy_html} that lets you deploy just HTML files and \link{cr_deploy_pkgdown} for running pkgdown websites.
#'
#' @param rmd_folder A folder of Rmd files within GitHub source that will be built into HTML for serving via \link[rmarkdown]{render}
#' @param html_folder A folder of html to deploy within GitHub source.  Will be ignored if rmd_folder is not NULL
#' @param edit_r If you want to change the R code to render the HTML, supply R code via a file or string of R as per \link{cr_buildstep_r}
#' @param region The region for cloud run
#' @param r_image The image that will run the R code from \code{edit_r}
#' @inheritParams cr_deploy_docker_trigger
#' @inheritParams cr_buildstep_run
#' @param repo A git repository defined in \link{cr_buildtrigger_repo}
#' @param timeout Timeout for the build
#' @param projectId The GCP projectId which will be deployed within
#' @family Deployment functions
#'
#' @details
#'
#' This lets you render the Rmd (or other R functions that produce HTML) in a folder for your repo, which will then be hosted on a Cloud Run enabled with nginx.  Each time you push to git with modified Rmd code, it will build the new HTML and push an update to the website.
#'
#' This default R code is rendered in the rmd_folder:
#'
#' \code{lapply(list.files('.', pattern = '.Rmd', full.names = TRUE),
#'       rmarkdown::render, output_format = 'html_document')}
#'
#'
#' @export
#' @examples
#' \dontrun{
#' cr_project_set("my-project")
#' cr_region_set("europe-west1")
#' your_repo <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner")
#' cr_deploy_run_website(your_repo, rmd_folder = "vignettes")
#'
#' # change the Rmd rendering to pkgdown
#' r <- "devtools::install();pkgdown::build_site()"
#'
#' cr_deploy_run_website(your_repo,
#'   image = paste0(your_repo, "-pkgdown"),
#'   rmd_folder = ".",
#'   edit_r = r
#' )
#' }
cr_deploy_run_website <- function(repo,
                                  image = paste0("website-", format(Sys.Date(), "%Y%m%d")),
                                  rmd_folder = NULL,
                                  html_folder = NULL,
                                  image_tag = "$SHORT_SHA",
                                  timeout = 600L,
                                  edit_r = NULL,
                                  r_image = "gcr.io/gcer-public/packagetools:latest",
                                  allowUnauthenticated = TRUE,
                                  region = cr_region_get(),
                                  projectId = cr_project_get()) {
  assert_that(
    xor(!is.null(rmd_folder), !is.null(html_folder)),
    is.buildtrigger_repo(repo)
  )

  image <- gsub("[^-a-zA-Z0-9\\/]", "", tolower(image))

  r <- "lapply(list.files('.', pattern = '.Rmd', full.names = TRUE),
       rmarkdown::render, output_format = 'html_document')"
  if (!is.null(edit_r)) {
    r <- edit_r
  }

  glob_f <- function(x) {
    if (x == ".") {
      return(x)
    }
    paste0(x, "/**")
  }

  rmd_step <- NULL
  if (!is.null(rmd_folder)) {
    rmd_step <- cr_buildstep_r(r,
      name = r_image,
      dir = rmd_folder,
      id = "render rmd"
    )
    html_folder <- rmd_folder
    glob <- glob_f(rmd_folder)
  } else {
    glob <- glob_f(html_folder)
  }

  repo_source <- repo

  cr_image <- lower_alpha_dash(image)
  run_image <- sprintf("%s:%s", make_image_name(image, projectId), image_tag)

  build_html <- cr_build_make(
    cr_build_yaml(
      steps = c(
        rmd_step,
        cr_buildstep_nginx_setup(html_folder),
        cr_buildstep_r("list.files()", dir = html_folder),
        cr_buildstep_docker(image,
          tag = image_tag,
          dir = html_folder,
          projectId = projectId,
          kaniko_cache = TRUE
        ),
        cr_buildstep_run(
          name = cr_image,
          image = run_image,
          allowUnauthenticated = allowUnauthenticated,
          region = region,
          concurrency = 80
        )
      )
    ),
    timeout = timeout
  )

  safe_name <- gsub("[^a-zA-Z1-9]", "-", image)
  cr_buildtrigger(build_html,
    name = safe_name,
    description = safe_name,
    trigger = repo_source,
    includedFiles = glob,
    projectId = projectId
  )
}


make_github_mirror <- function(x) {
  paste0("github_", tolower(gsub("/", "_", x)))
}

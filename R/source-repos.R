#' List source repositories available under a project
#'
#' @param projectId The projectId that holds the repositories
#'
#' @export
#' @importFrom googleAuthR gar_api_generator gar_api_page
cr_sourcerepo_list <- function(projectId = cr_project_get()) {
  f <- gar_api_generator(
    sprintf("https://sourcerepo.googleapis.com/v1/projects/%s/repos", projectId),
    "GET",
    data_parse_function = function(x) x$repos
  )

  page_f <- function(x) {
    x$nextPageToken
  }

  pages <- gar_api_page(f,
    page_f = page_f,
    page_method = "param",
    page_arg = "pageToken"
  )

  Reduce(rbind, pages)
}

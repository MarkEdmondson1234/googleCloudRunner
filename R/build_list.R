#' Lists the build
#'
#' Get a list of builds within your project
#'
#' @param projectId ID of the project
#' @param pageSize How many builds to fetch per page
#' @param filter Text filter for the list - use \code{cr_build_list_filter()} or a raw string
#' @param data_frame_output If TRUE will output a data.frame of a subset of info from the builds, merged with the list of triggers from \link{cr_buildtrigger_list}.  Set to FALSE to return a list of Build objects similar to output from \link{cr_build_status}
#'
#' @details
#'
#' When \code{data_frame_output=TRUE} results are sorted with the latest buildStartTime in the first row
#'
#' If filter is \code{NULL} then this will return all historic builds.  To use filters, ensure you use \code{""} and not \code{''} to quote the fields e.g. \code{'status!="SUCCESS"'} and \code{'status="SUCCESS"'} - see \href{https://cloud.google.com/build/docs/view-build-results#filtering_build_results_using_queries}{Filtering build results docs}.  \code{cr_build_list_filter} helps you construct valid filters.  More complex filters can be done using a combination of \link{paste} and \code{cr_build_list_filter()} - see examples
#'
#' @seealso \url{https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds/list}
#'
#' @importFrom googleAuthR gar_api_generator gar_api_page
#' @import assertthat
#' @export
#' @family Cloud Build functions
#' @examples
#' \dontrun{
#'
#' # merge with buildtrigger list
#' cr_build_list()
#'
#' # output a list of build objects
#' cr_build_list(data_frame_output = FALSE)
#'
#' # output a list of builds that failed using raw string
#' cr_build_list('status!="SUCCESS"')
#'
#' # output builds for a specific trigger using raw string
#' cr_build_list('trigger_id="af2c7ddc-e4eb-4170-b938-a4babb53bac6"')
#'
#' # use cr_build_list_filter to help validate filters
#' failed_builds <- cr_build_list_filter("status", "!=", "SUCCESS")
#' cr_build_list(failed_builds)
#'
#' f1 <- cr_build_list_filter(
#'   "trigger_id", "=", "af2c7ddc-e4eb-4170-b938-a4babb53bac6"
#' )
#' cr_build_list(f1)
#'
#' # do AND (and other) filters via paste() and cr_build_list_filter()
#' cr_build_list(paste(f1, "AND", failed_builds))
#'
#' # builds in last 5 days
#' last_five <- cr_build_list_filter("create_time", ">", Sys.Date() - 5)
#' cr_build_list(last_five)
#'
#' # builds in last 60 mins
#' last_hour <- cr_build_list_filter("create_time", ">", Sys.time() - 3600)
#' cr_build_list(last_hour)
#'
#' # builds for this package's buildtrigger
#' gcr_trigger_id <- "0a3cade0-425f-4adc-b86b-14cde51af674"
#' gcr_bt <- cr_build_list_filter(
#'   "trigger_id",
#'   value = gcr_trigger_id
#' )
#' gcr_builds <- cr_build_list(gcr_bt)
#'
#' # get logs for last build
#' last_build <- gcr_builds[1, ]
#' last_build_logs <- cr_build_logs(log_url = last_build$bucketLogUrl)
#' tail(last_build_logs, 10)
#' }
cr_build_list <- function(filter = NULL,
                          projectId = cr_project_get(),
                          pageSize = 1000,
                          data_frame_output = TRUE) {
  url <- sprintf(
    "https://cloudbuild.googleapis.com/v1/projects/%s/builds",
    projectId
  )

  pars <- list(
    pageSize = pageSize
  )
  if (!is.null(filter)) {
    pars <- c(list(filter = filter), pars)
  }

  # cloudbuild.projects.builds.list
  f <- gar_api_generator(url, "GET",
    pars_args = pars,
    data_parse_function = function(x) x,
    simplifyVector = FALSE,
    checkTrailingSlash = FALSE
  )

  o <- f()

  # no paging required, return
  if (is.null(o$nextPageToken)) {
    build_list <- o$builds
  } else {
    # need to page
    pars <- c(list(pageToken = o$nextPageToken), pars)
    # cloudbuild.projects.builds.list
    f2 <- gar_api_generator(url, "GET",
      pars_args = pars,
      data_parse_function = function(x) x,
      simplifyVector = FALSE,
      checkTrailingSlash = FALSE
    )
    results <- gar_api_page(f2,
      page_f = function(x) x$nextPageToken,
      page_method = "param",
      page_arg = "pageToken"
    )

    # 149
    if (length(results) == 1 && length(results[[1]]) == 0) {
      build_list <- o$builds
    } else {
      build_list <- unlist(lapply(results, function(x) x$builds), recursive = FALSE)
    }
  }

  if (length(build_list) == 0) {
    myMessage("No builds found", filter, level = 3)
    return(NULL)
  }

  bs <- lapply(build_list, as.gar_Build)
  ids <- unlist(lapply(bs, function(x) x$id))
  objs <- stats::setNames(bs, ids)

  # a list of build objects
  if (!data_frame_output) {
    return(objs)
  }

  myMessage("Parsing build objects into data.frame", level = 2)
  # make a data.frame output
  b_df <- Reduce(
    rbind,
    lapply(
      ids,
      function(y) {
        x <- objs[[y]]
        tryCatch(
          data.frame(
            buildId = if_null_na(x$id),
            status = if_null_na(x$status),
            projectId = if_null_na(x$projectId),
            buildCreateTime = if_null_na(timestamp_to_r(x$createTime)),
            buildStartTime = if_null_na(timestamp_to_r(x$startTime)),
            buildFinishTime = if_null_na(timestamp_to_r(x$finishTime)),
            timeout = if_null_na(x$timeout),
            logsBucket = if_null_na(x$logsBucket),
            buildTriggerId = if_null_na(x$buildTriggerId),
            logUrl = if_null_na(x$logUrl),
            bucketLogUrl = make_bucket_log_url(x),
            stringsAsFactors = FALSE
          ),
          error = function(err) {
            str(x)
            warning("Could not parse build list object: ", err$message)
            return(NULL)
          }
        )
      }
    )
  )

  bts_df <- cr_buildtrigger_list(projectId = projectId)

  # merge on buildTriggerId
  merged <- merge(b_df, bts_df, all.x = TRUE, sort = FALSE)

  merged[order(merged$buildStartTime, decreasing = TRUE), ]
}

#' Helper to parse filters for Build listings
#'
#' cr_build_list_filter outputs valid filters for \code{cr_build_list}'s filter argument
#'
#' @param field The field you want to filter on.  Will validate.
#' @param operator The type of comparision for the filter
#' @param value The value for the filter's field. Auto-formats \code{POSIXct} and \code{Date} objects
#'
#' @details
#'
#' Use \link{POSIXct} via functions like \link{Sys.time} to have them formatted into valid timestamps for time related fields, or \link{Date} objects via functions like \link{Sys.Date}
#'
#' @rdname cr_build_list
#' @export
cr_build_list_filter <- function(field,
                                 operator = c("=", "!=", ">", ">=", "<", "<="),
                                 value) {
  if (is.null(field)) {
    return(NULL)
  }

  operator <- match.arg(operator)

  if (is.buildtrigger_repo(field)) {
    # create multiple filters based on repo
    return(
      cr_build_list_filter(
        "source.repo_source.repo_name",
        "=",
        paste0(field$repo$owner, "/", field$repo$name)
      )
    )
  } else {
    assert_that(is.string(field))
  }


  the_fields <- c(
    "status",
    "build_id",
    "trigger_id",
    "source.storage_source.bucket",
    "source.storage_source.object",
    "source.repo_source.repo_name",
    "source.repo_source.branch_name",
    "source.repo_source.tag_name",
    "source.repo_source.commit_sha",
    "source_provenance.resolved_repo_source.commit_sha",
    "results.images.name",
    "results.images.digest",
    "options.requested_verify_option",
    "tags",
    "images",
    "create_time",
    "start_time",
    "finish_time"
  )

  if (!field %in% the_fields) {
    stop(sprintf(
      "Field %s not present in supported fields: \n%s",
      field, paste(the_fields, collapse = "\n")
    ), call. = FALSE)
  }

  if (inherits(value, "POSIXct") || inherits(value, "Date")) {
    value <- format(value, format = "%Y-%m-%dT%H:%M:%S+00:00", tz = "UTC")
  }

  assert_that(is.string(value))

  sprintf('%s %s "%s"', field, operator, value)
}

if_null_na <- function(thing) {
  if (is.null(thing)) {
    return(NA)
  }
  thing
}

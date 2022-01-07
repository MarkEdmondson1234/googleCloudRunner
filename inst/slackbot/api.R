library(googleAnalyticsR)
library(dplyr)
library(httr)

# the function will be called from the endpoints
do_ga <- function(ga_id) {
  # get last years referrer data
  two_years <- google_analytics(
    ga_id,
    date_range = c(Sys.Date() - 365, Sys.Date()),
    dimensions = c("date", "fullReferrer", "landingPagePath"),
    metrics = "sessions",
    rows_per_call = 50000,
    max = -1)

  last7Days <- two_years %>% filter(date >= Sys.Date() - 7) #nolint
  previousDays <- two_years %>% filter(date < Sys.Date() - 7) #nolint

  # the referrers seen in last30days but not previously
  new_refs <- setdiff(unique(last7Days$fullReferrer),
                      unique(previousDays$fullReferrer))

  last_7_new_refs <- last7Days %>%
    filter(fullReferrer %in% new_refs)

  last_7_new_refs
}

#' @get /
#' @serializer html
function() {
  "<html><h1>It works!</h1></html>"
}


#' @get /last-30-days
#' @serializer csv
function(ga_id) {
  # get last years referrer data
  do_ga(ga_id)
}

#' @get /trigger-slack
#' @serializer json
function(ga_id) {
  # get last years referrer data
  last_30_new_refs <- do_ga(ga_id)

  the_data <- unique(last_30_new_refs$fullReferrer)

  the_body <- list(
    text = paste0("Google Analytics Last 7Days New Referrals\n",
                  "```\n",
                  paste0(collapse = "\n", the_data),
                  "\n```\n")
  )
  # get the Slack URL from an env var
  slack_url <- Sys.getenv("SLACK_URL")
  res <- POST(slack_url, body = the_body, encode = "json")

  list(slack_http_response = res$status_code)
}

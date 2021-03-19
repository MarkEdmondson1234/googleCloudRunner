library(googleAnalyticsR)
library(dplyr)
library(httr)

# the function will be called from the endpoints
do_ga <- function(ga_id){
  # get last years referrer data
  two_years <- google_analytics(
    ga_id,
    date_range = c(Sys.Date()-(365), Sys.Date()),
    dimensions = c("date","fullReferrer","landingPagePath"),
    metrics = "sessions",
    rows_per_call = 50000,
    max = -1)

  last30Days <- two_years %>% filter(date >= Sys.Date() - 30)
  previousDays <- two_years %>% filter(date < Sys.Date() - 30)

  # the referrers seen in last30days but not previously
  new_refs <- setdiff(unique(last30Days$fullReferrer),
                      unique(previousDays$fullReferrer))

  last_30_new_refs <- last30Days %>%
    filter(fullReferrer %in% new_refs)

  last_30_new_refs
}

#' @get /
#' @serializer html
function(){
  "<html><h1>It works!</h1></html>"
}


#' @get /last-30-days
#' @serializer csv
function(ga_id){
  # get last years referrer data
  do_ga(ga_id)
}

#' @get /trigger-slack
#' @serializer json
function(ga_id){
  # get last years referrer data
  last_30_new_refs <- do_ga(ga_id)

  the_body <- list(
    text = paste0("```\n",
                  paste0(collapse = "\n",knitr::kable(last_30_new_refs)),
                  "```\n")
  )

  POST(slack_url, body = the_body, encode = "json")
}

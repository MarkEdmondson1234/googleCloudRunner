if (Sys.getenv("PORT") == "") Sys.setenv(PORT = 8000)

#auth via BQ_AUTH_FILE environment argument
library(bigQueryR)
library(xts)
library(forecast)

#' @get /
#' @html
function() {
  "<html><h1>It works!</h1></html>"
}


#' @get /hello
#' @html
function() {
  "<html><h1>hello world</h1></html>"
}

#' @get /covid_traffic
#' @param industry the industry to filter results down to e.g "Software"
#' @param region the region to filter results down to e.g "Europe"
function(region=NULL, industry=NULL, bqds = NULL, bqtbl = NULL) {

  if(any(is.null(region), is.null(industry))){
    stop("Must supply region and industry parameters")
  }

  # to handle spaces
  region <- URLdecode(region)
  industry <- URLdecode(industry)

  sql <- sprintf("SELECT date, industry, percent_of_baseline
                 FROM `bigquery-public-data.covid19_geotab_mobility_impact.commercial_traffic_by_industry`
                 WHERE region = '%s' order by date LIMIT 1000", region)

  message("Query: ", sql)

  traffic <- bqr_query(
    query = sql,
    datasetId = "covid19_geotab_mobility_impact",
    useLegacySql = FALSE,
    maxResults = 10000
  )

  # filter to industry in R this time
  test_data <- traffic[traffic$industry == industry,
                       c("date", "percent_of_baseline")]

  tts <- xts(test_data$percent_of_baseline,
             order.by = test_data$date,
             frequency = 7)

  # replace with long running sophisticated analysis
  model <- forecast(auto.arima(tts))

  # output a list that can be turned into JSON via jsonlite::toJSON
  o <- list(
    params = c(region, industry),
    x = model$x,
    mean = model$mean,
    lower = model$lower,
    upper = model$upper
  )

  message("Return: ", jsonlite::toJSON(o))

  if (is.null(bqds) || is.null(bqtbl)) {
    # return data directly
    return(o)
  }

  # we upload result to bigQuery
  bqr_upload_data(
    datasetId = bqds,
    tableId = bqtbl,
    upload_data = list(o),
    sourceFormat = "NEWLINE_DELIMITED_JSON",
    wait = FALSE,
    autodetect = TRUE
  )



}

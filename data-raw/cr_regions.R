## code to prepare `cr_regions` dataset goes here

library(httr)
library(rvest)
library(xml2)
url = "https://cloud.google.com/run/docs/locations"
res = httr::GET(url)
cr_regions = httr::content(res) %>%
  html_nodes(css= "#subject-to-tier-2-pricing+ ul code , #subject-to-tier-1-pricing+ ul code")
cr_regions = html_text(cr_regions)

cr_regions <- c("us-central1",
             "asia-northeast1",
             "europe-west1",
             "us-east1")
cr_regions <- c(cr_regions,
             "asia-east1", "asia-northeast1", "asia-northeast2", "europe-north1",
             "europe-west1", "europe-west4", "us-central1", "us-east1", "us-east4",
             "us-west1", "asia-east2", "asia-northeast3", "asia-southeast1",
             "asia-southeast2 ", "asia-south1", "asia-south2", "australia-southeast1",
             "australia-southeast2", "europe-central2", "europe-west2", "europe-west3",
             "europe-west6", "northamerica-northeast1", "northamerica-northeast2",
             "southamerica-east1", "us-west2", "us-west3", "us-west4")
cr_regions <- unique(cr_regions)

usethis::use_data(cr_regions, overwrite = TRUE)

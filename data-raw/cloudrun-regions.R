regions <- read.csv("data-raw/regions.txt")
cr_regions <- regions$NAME
usethis::use_data(cr_regions, overwrite=TRUE)

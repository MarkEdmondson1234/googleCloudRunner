zones <- read.csv("data-raw/zones.txt", header = FALSE)
cr_zones <- zones[[1]]
usethis::use_data(cr_zones, overwrite = TRUE)

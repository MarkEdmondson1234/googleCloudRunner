library(dplyr)

cat("A scheduled script: ", Sys.time())

select(mtcars, mpg, cyl)

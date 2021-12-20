if(Sys.getenv("PORT") == "") Sys.setenv(PORT = 8000) #local testing

#' Plot out data from the mtcars
#' @param cyl If provided, passed into Rmd rendering parameters
#' @get /
#' @serializer html
function(cyl = NULL){

  # to avoid caching a timestamp is added
  outfile <- sprintf("mtcars-%s.html", gsub("[^0-9]", "", Sys.time()))

  # render markdown to the file
  rmarkdown::render(
    "mtcars.Rmd",
    params = list(cyl = cyl),
    envir = new.env(),
    output_file = outfile
  )

  # read html of file back in and use as response for plumber
  readChar(outfile, file.info(outfile)$size)
}

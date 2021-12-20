pr <- plumber::plumb("api.R")
pr$run(host = "0.0.0.0", port = as.numeric(Sys.getenv("PORT")), swagger = TRUE)

pr <- plumber::plumb("api.R")
v <- vetiver::vetiver_pin_read(pins::board_folder("pins"), name = "sacramento_rf")
pr <- vetiver::vetiver_pr_predict(pr, v, debug = TRUE)
pr$run(host = "0.0.0.0", port = as.numeric(Sys.getenv("PORT")), swagger = TRUE)

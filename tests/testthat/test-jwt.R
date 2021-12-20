test_that("[Online] JWT creation", {
  skip_on_ci()
  skip_on_cran()

  test_url <- "https://fake.a.run.app"
  jwt <- cr_jwt_create(test_url)
  expect_true(is.character(jwt))

  token <- cr_jwt_token(jwt, test_url)
  expect_true(is.character(token))
})

test_that("[Online] JWT fetches", {
  skip_on_ci()
  skip_on_cran()
  cr <- cr_run_get("parallel-cloudrun")

  # Interact with the authenticated Cloud Run service
  the_url <- cr$status$url
  jwt <- cr_jwt_create(the_url)

  # needs to be recreated every 60mins
  token <- cr_jwt_token(jwt, the_url)

  # call Cloud Run with token
  res <- cr_jwt_with_httr(
    httr::GET("https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=North%20America&industry=Transportation%20(non-freight)"),
    token
  )
  o <- httr::content(res)

  expect_true(inherits(o, "list"))

  all_urls <- c(
    "https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=North%20America&industry=Transportation%20(non-freight)",
    "https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=Europe&industry=Transportation%20(non-freight)",
    "https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=South%20America&industry=Transportation%20(non-freight)",
    "https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=Australia&industry=Transportation%20(non-freight)",
    "https://parallel-cloudrun-ewjogewawq-ew.a.run.app/covid_traffic?region=North%20America&industry=Software"
  )

  res2 <- cr_jwt_async(all_urls, token = token)
  expect_true(inherits(res2, "list"))
  # response is json starting with {"params" ...}
  expect_true(grepl('^\\{\\"params\\"', res2[[1]]))
})

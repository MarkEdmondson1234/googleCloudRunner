#' Create a JSON Web Token (JWT) from your service client and call Google services
#'
#' This can be used to call authenticated services such as Cloud Run.
#'
#' @param the_url The URL of the service you want to call
#' @param service_json The account service key JSON that will be used to generate the JWT
#'
#' @seealso \href{https://cloud.google.com/run/docs/authenticating/service-to-service}{Service-to-service authentication on GCP}
#'
#' @details For certain Google services a JWT is needed to authenticate access, which is distinct from OAuth2.  An example of this is authenticated Cloud Run such as deployed when using \link{cr_run} and parameter \code{allowUnauthenticated = FALSE}.  These functions help you call your services by generating the JWT from your service account key.
#'
#' The token is set to expire in 1 hour, so it will need refreshing before then by calling this function again.
#'
#' @export
#' @family Cloud Run functions
#' @examples
#' \dontrun{
#'
#' # The private authenticated access only Cloud Run service
#' the_url <- "https://authenticated-cloudrun-ewjogewawq-ew.a.run.app/"
#'
#' # creating the JWT and token
#' jwt <- cr_jwt_create(the_url)
#' token <- cr_jwt_token(jwt, the_url)
#'
#' # call Cloud Run app using token with any httr verb
#' library(httr)
#' res <- cr_jwt_with_httr(
#'   GET("https://authenticated-cloudrun-ewjogewawq-ew.a.run.app/hello"),
#'   token
#' )
#' content(res)
#'
#' # call Cloud Run app with curl - you can pass in a curl handle
#' library(curl)
#' h <- new_handle()
#' handle_setopt(h, customrequest = "PUT")
#' handle_setform(h, a = "1", b = "2")
#' h <- cr_jwt_with_curl(h, token = token)
#' r <- curl_fetch_memory("https://authenticated-cloudrun-ewjogewawq-ew.a.run.app/hello", h)
#' cat(rawToChar(r$content))
#'
#' # use curls multi-asynch functions
#' many_urls <- paste0(
#'   "https://authenticated-cloudrun-ewjogewawq-ew.a.run.app/hello",
#'   paste0("?param="), 1:6
#' )
#' cr_jwt_async(many_urls, token = token)
#' }
#'
#' @importFrom jose jwt_claim jwt_encode_sig
#' @importFrom jsonlite fromJSON
cr_jwt_create <- function(the_url,
                          service_json = Sys.getenv("GCE_AUTH_FILE")) {
  aj <- fromJSON(service_json)
  headers <- list(
    "kid" = aj$private_key_id,
    "alg" = "RS256",
    "typ" = "JWT" # Google uses SHA256withRSA
  )

  claim <- jwt_claim(
    target_audience = the_url,
    aud = "https://www.googleapis.com/oauth2/v4/token",
    exp = unclass(Sys.time() + 3600),
    iss = aj$client_email,
    sub = aj$client_email
  )

  jwt_encode_sig(claim,
    key = aj$private_key,
    header = headers
  )
}

#' @param signed_jwt A JWT created from \link{cr_jwt_create}
#' @rdname cr_jwt_create
#' @export
#' @importFrom httr POST content
cr_jwt_token <- function(signed_jwt, the_url) {
  auth_url <- "https://www.googleapis.com/oauth2/v4/token"

  params <- list(
    grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion = signed_jwt
  )

  res <- POST(auth_url, body = params)

  content(res)$id_token
}

#' @param req A \code{httr} request to the service running on \code{the_url}, using httr verbs such as \link[httr]{GET}
#' @param token The token created via \link{cr_jwt_token}
#' @rdname cr_jwt_create
#' @export
#' @importFrom httr with_config add_headers
cr_jwt_with_httr <- function(req, token) {
  with_config(
    config = add_headers(
      Authorization = sprintf("Bearer %s", token)
    ),
    req
  )
}

#' @param h A curl handle such as set with \link[curl]{new_handle}
#' @param token The token created via \link{cr_jwt_token}
#' @rdname cr_jwt_create
#' @export
#' @importFrom curl new_handle handle_setheaders
cr_jwt_with_curl <- function(h = curl::new_handle(), token) {
  handle_setheaders(h,
    Authorization = sprintf("Bearer %s", token)
  )

  h
}

#' @param urls URLs to request asynchronously
#' @param token The token created via \link{cr_jwt_token}
#' @param ... Other arguments passed to \link[curl]{new_handle}
#' @export
#' @rdname cr_jwt_create
#' @importFrom curl new_handle curl_fetch_multi multi_run new_pool
cr_jwt_async <- function(urls, token, ...) {
  failure <- function(str) {
    cat(paste("Failed request:", str), file = stderr())
  }

  results <- list()
  success <- function(x) {
    if (x$status_code == 200) {
      results <<- append(results, list(rawToChar(x$content)))
    } else {
      myMessage(x$status_code, "failure for request", x$url, level = 3)
    }
  }
  pool <- new_pool()

  lapply(urls, function(x) {
    myMessage("Calling asynch: ", x, level = 3)
    h <- new_handle(url = x, ...)
    h <- cr_jwt_with_curl(h = h, token = token)
    curl_fetch_multi(x,
      done = success, fail = failure,
      handle = h, pool = pool
    )
  })

  multi_run(pool = pool)

  results
}

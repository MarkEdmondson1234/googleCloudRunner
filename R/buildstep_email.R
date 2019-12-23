#' Send an email in a Cloud Build step
#'
#' This uses \link[blastula]{smtp_send} to send markdown emails.
#'
#' @param message The message markdown
#' @param from from email
#' @param to to email
#' @param subject subject email
#' @inheritParams cr_buildstep_decrypt
#'
#' @details
#'
#' You will need to create a credentials file locally first, then deploy it to Key Management Store.  This will be used to send the emails securely.
#'
cr_buildstep_email <- function(message,
                               from,
                               to,
                               subject,
                               cipher = "email_creds.enc",
                               plain = "email_creds",
                               keyring = "my_keyring",
                               key = "email_creds",
                               location="global",
                               ...){
  r <- sprintf(
     ""
  )

  c(
    cr_buildstep_decrypt(
      cipher = cipher,
      plain = plain,
      keyring = keyring,
      key = key,
      location = location,
      ...
    ),
    cr_buildstep_r(r)
  )

}

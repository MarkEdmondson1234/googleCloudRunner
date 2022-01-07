library(shiny)
library(searchConsoleR)
library(googleAuthR)

gar_set_client(web_json = "mark-edmondson-gde-web-client.json",
               scopes = "https://www.googleapis.com/auth/webmasters")

ui <- fluidPage(
  googleAuth_jsUI("auth", login_text = "Login to Google"),
  tableOutput("sc_accounts"),
  uiOutput("select_website"),
  tableOutput("sc_data")
)

server <- function(input, output, session) {
  auth <- callModule(googleAuth_js, "auth") #nolint

  sc_accounts <- reactive({
    req(auth()) #nolint

    with_shiny(
      list_websites,
      shiny_access_token = auth()
    )

  })

  output$sc_accounts <- renderTable({
    sc_accounts()
  })

  output$select_website <- renderUI({
    req(sc_accounts()) #nolint

    selectInput("website", "Select a website",
                choices = sc_accounts()$siteUrl)
  })

  sc_data <- reactive({
    req(input$website) #nolint

    o <- with_shiny(
      search_analytics,
      siteURL = input$website,
      startDate = as.Date("2020-06-01"),
      endDate = as.Date("2020-06-07"),
      dimensions = c("date"),
      searchType = "web",
      rowLimit = 200,
      dimensionFilterExp = NULL,
      shiny_access_token = scr_auth(auth()) # to put in Shiny environment
    )

    o$date <- as.character(o$date)
    o

  })

  output$sc_data <- renderTable({
    sc_data()
  })

}

shinyApp(ui = ui, server = server)

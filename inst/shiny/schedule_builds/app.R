library(shiny)
library(shinyjs)
library(googleCloudRunner)

ui <- fluidPage(
  shinyjs::useShinyjs(),
  titlePanel("Cloud Build Scheduler"),

  sidebarLayout(
    sidebarPanel(
      helpText("Upload a cloudbuild.yml file to schedule"),
      fileInput("cbfile", "cloudbuild.yml",
                accept = c(
                  "text/yaml",
                  "text/x-yaml",
                  "application/x-yaml",
                  "text/vnd.yaml"
                )),
      textInput("schedule_name", label = "Schedule name", value = "my-schedule"),
      textInput("cron", "cron schedule", value = "15 9 * * *"),
      uiOutput("logs_link")
  ),
    mainPanel(
      helpText("This app will take an existing cloudbuild.yml, validate a build and then schedule"),
      shinyjs::hidden(h3(id = "working", "Building...")),
      p(textOutput("validated")),
      textOutput("scheduled")
  )
)
)

server <- function(input, output, session){

  do_build <- reactive({
    req(input$cbfile)
    bb <- input$cbfile$datapath
    cr_build(bb)
  })

  output$logs_link <- renderUI({
    req(do_build())

    a(href=bb$metadata$build$logUrl, "Build Log")

  })

  built <- reactive({
    req(do_build())
    shinyjs::show("working")
    cr_build_wait(do_build())
  })

  output$validated <- renderText({
    req(built())
    shinyjs::hide("working")

    if(built()$status == "SUCCESS"){
      return("Build validated")
    }

    "Build error - check logs"
  })

  output$scheduled <- renderText({
    req(built())

    if(built()$status == "SUCCESS"){
      bb <- cr_build_schedule_http(built())
      x <- cr_schedule(input$schedule_name,
                  schedule = input$cron,
                  httpTarget = bb,
                  description = "Scheduled via googleCloudRunner shiny",
                  overwrite = TRUE)

      return(
        paste(
        "==CloudScheduleJob==\n",
        "name: ", x$name,
        "state: ", x$state,
        "httpTarget.uri: ", x$httpTarget$uri,
        "httpTarget.httpMethod: ", x$httpTarget$httpMethod,
        "userUpdateTime: ", x$userUpdateTime,
        "schedule: ", x$schedule,
        "timezone: ", x$timeZone)
      )
    }

    "Not scheduling"

    })
}


shinyApp(ui, server)

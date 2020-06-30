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
      textInput("schedule_name", label = "Schedule name",
                value = paste0("my-schedule-", format(Sys.time(), "%Y%m%d%H%M%S"))),
      textInput("cron", "cron schedule", value = "15 9 * * *"),
      h4("Project:", cr_project_get()),
      p(a(href=sprintf("https://console.cloud.google.com/cloudscheduler?project=%s",
                       cr_project_get()), "Project schedule listings")),
      p(a(href=sprintf("https://console.cloud.google.com/cloud-build/builds?project=%s",
              cr_project_get()), "Project build history")),
      uiOutput("logs_link")
  ),
    mainPanel(
      helpText("This app will take an existing cloudbuild.yml, validate a build and then schedule it"),
      helpText("Create the cloudbuild.yml file either via",
               a(href="https://code.markedmondson.me/googleCloudRunner/reference/cr_build_write.html",
                 "googleCloudRunner's cr_build_write() function"),
               "or manually following the",
               a(href = "https://cloud.google.com/cloud-build/docs/build-config",
                 "Cloud Build yaml schema")),
      shinyjs::hidden(h3(id = "working", "Building...")),
      p(textOutput("validated")),
      uiOutput("scheduled")
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

    a(href=do_build()$metadata$build$logUrl, "Build Log")

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

  output$scheduled <- renderUI({
    req(built())

    if(built()$status == "SUCCESS"){
      bb <- cr_build_schedule_http(built())
      x <- cr_schedule(input$schedule_name,
                  schedule = input$cron,
                  httpTarget = bb,
                  description = "Scheduled via googleCloudRunner shiny",
                  overwrite = TRUE)

      if(!is.null(x$state))
      return(
        tagList(
          h3("Cloud Build Scheduled"),
          tags$ul(
            tags$li(paste("name: ", x$name)),
            tags$li(paste("state: ", x$state)),
            tags$li(paste("userUpdateTime: ", x$userUpdateTime)),
            tags$li(paste("schedule: ", x$schedule)),
            tags$li(paste("timezone: ", x$timeZone)),
          )

        )
      )
    }

    h3("Build Error - not scheduling - see build logs")

    })
}


shinyApp(ui, server)

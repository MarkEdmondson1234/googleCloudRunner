cr_deploy_gadget <- function(){

  ui <- miniUI::miniPage(
    miniUI::gadgetTitleBar("googleCloudRunner Deploy"),
    miniUI::miniTabstripPanel(
      miniUI::miniTabPanel("R script", icon = shiny::icon("r-project"),
        miniUI::miniContentPanel(
          shiny::fileInput("rFile",
                           "Select R File",
                           accept = c(".R",".r")),
          shiny::textInput("rSchedule", label = "cron Schedule",
                           value = "15 8 * * *"),
          shiny::textInput("rImage", label = "Docker image to use",
                           value = "rocker/verse"),
          shiny::radioButtons("rSource", "Data Source",
                             choices = c("None",
                                         "CloudRepository",
                                         "CloudStorage"),
                             inline = TRUE),
          shiny::uiOutput("rSourceDyn"),
          shiny::numericInput("rTimeout", label = "Timeout",
                              value = 600,
                              min = 100, max = 3600)
        )
      ),
      miniUI::miniTabPanel("plumber API", icon = shiny::icon("wrench"),
        miniUI::miniContentPanel(
          shiny::fileInput("apiFile",
                           "Select plumber api.R file",
                           accept = c(".R",".r")),
          shiny::textInput("apiImage", label = "Docker image to build",
                           value = paste0("gcr.io/",
                                          cr_project_get(),
                                          "/your-r-api")),
          shiny::br()
        )
      ),
      miniUI::miniTabPanel("Dockerfile", icon = shiny::icon("docker"),
        miniUI::miniContentPanel(
          shiny::fileInput("dockerFile","Select Dockerfile"),
            shiny::textInput("dockerImage", label = "Docker image to build",
              value = paste0("gcr.io/",
                             cr_project_get(),
                             "/my-image"))
          )
      )
    )

  )

  server <- function(input, output, session) {

    ## Your reactive logic goes here.
    output$rSourceDyn <- shiny::renderUI({
      shiny::req(input$rSource)

      ss <- input$rSource
      if(ss == "None"){
        return(NULL)
      } else if(ss == "CloudRepository"){
        return(
          shiny::tagList(
            shiny::textInput("source1", label = "repoName",
                             placeholder = "MarkEdmondson1234/googleCloudRunner"),
            shiny::textInput("source2", label = "branchName regex",
                             value = ".*")
          )
        )
      } else if(ss == "CloudStorage"){
        return(shiny::tagList(
          shiny::textInput("source1", label = "bucket",
                           value = cr_bucket_get()),
          shiny::textInput("source2", label = "tar File",
                           placeholder = "my_code.tar.gz")
        ))
      }

    })



    shiny::observeEvent(input$done, {

      shiny::stopApp()
    })
  }

  viewer <- shiny::paneViewer()
  shiny::runGadget(ui, server, viewer = viewer)

}

cr_deploy_gadget <- function(){

  ui <- miniUI::miniPage(
    miniUI::gadgetTitleBar("Setup googleCloudRunner Deploy"),
    miniUI::miniTabstripPanel(
      miniUI::miniTabPanel("R script", icon = shiny::icon("r-project"),
        miniUI::miniContentPanel(
          shiny::helpText("Configure arguments passed to cr_deploy_r()"),
          shiny::fileInput("rFile",
                           "Select R File",
                           accept = c(".R",".r")),
          shiny::helpText("Set schedule to empty to run immediatly"),
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
                           shiny::textOutput("wd"),
        miniUI::miniContentPanel(

          shiny::helpText("Configure arguments passed to cr_deploy_run()"),
          shiny::textInput("apiFile",
                           label = "Select folder with api.R file",
                           placeholder = "plumber/"),
          shiny::textInput("apiImage", label = "Docker image to build",
                           placeholder = paste0("gcr.io/",
                                          cr_project_get(),
                                          "/your-r-api")),
          shiny::br()
        )
      ),
      miniUI::miniTabPanel("Dockerfile", icon = shiny::icon("docker"),
                           shiny::textOutput("wd"),
        miniUI::miniContentPanel(
          shiny::textOutput("wd"),
          shiny::helpText("Configure arguments passed to cr_deploy_docker()"),
          shiny::textInput("dockerFile",
                           label = "Select folder with Dockerfile",
                           placeholder = "docker/"),
            shiny::textInput("dockerImage", label = "Docker image to build",
                             placeholder = paste0("gcr.io/",
                             cr_project_get(),
                             "/my-image"))
          )
      )
    )

  )

  server <- function(input, output, session) {

    output$wd <- shiny::renderText({getwd()})

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

      if(!is.null(input$rFile)){
        source <- switch(input$rSource,
          None = NULL,
          CloudRepository = cr_build_source(RepoSource(input$source1,
                                                       branchName = input$source2)),
          CloudStorage = cr_build_source(StorageSource(bucket = input$source1,
                                                       object = input$source2)))
        the_file <- input$rFile

        shiny::stopApp(
          cr_deploy_r(the_file$datapath,
                      schedule = if(input$rSchedule =="") NULL else input$rSchedule,
                      source = source,
                      run_name = input$name,
                      r_image = input$rImage,
                      timeout = input$rTimeout)
        )
      }

      if(!is.null(input$apiFile)){
        the_file <- input$apiFile
        folder <- dirname(the_file$name)

        shiny::stopApp(
          cr_deploy_run(folder, image_name = input$apiImage)
        )
      }

      if(!is.null(input$dockerFile)){
        the_file <- input$dockerFile
        folder <- dirname(the_file$datapath)

        shiny::stopApp(
          cr_deploy_docker(folder, image_name = input$dockerImage)
          )
      }

    })
  }

  viewer <- shiny::paneViewer()
  shiny::runGadget(ui, server, viewer = viewer)

}

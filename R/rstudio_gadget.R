#' Launch the googleCloudRunner deployment RStudio gadget
#' @import assertthat
#' @export
cr_deploy_gadget <- function(){

  assert_that(
    cr_project_get() != "",
    cr_bucket_get() != "",
    cr_region_get() != "",
    Sys.getenv("GCE_AUTH_FILE") != ""
  )

  image_name_helper <- function(dockerImage,
                                dockerFile,
                                dockerProject,
                                dockerTag){
    if(dockerImage == ""){
      d_image <- basename(dockerFile)
    } else {
      d_image <- dockerImage
    }
    image <- paste0("gcr.io/", dockerProject, "/", d_image)
    if(!is.null(dockerTag)){
      # only for display purposes
      image <- paste0(image, ":", dockerTag)
    }
    image
  }

  ui <- miniUI::miniPage(
    miniUI::gadgetTitleBar("Setup googleCloudRunner Deploy"),
    miniUI::miniTabstripPanel(between = miniUI::miniButtonBlock(
      shiny::numericInput("rTimeout",
                         label = "Build Timeout",
                         value = 600,
                         min = 100,
                         max = 3600, width = "100px")),
      miniUI::miniTabPanel("R script", icon = shiny::icon("r-project"),
        miniUI::miniContentPanel(
          shiny::helpText("Configure arguments passed to cr_deploy_r()"),
          shiny::fileInput("rFile",
                           "Select R File",
                           accept = c(".R",".r")),
          shiny::helpText("Set schedule to empty to run immediatly"),
          shiny::textInput("rSchedule", label = "cron Schedule",
                           value = "15 8 * * *"),
          shiny::textInput("rImage", label = "R docker image",
                           value = "rocker/verse"),
          shiny::radioButtons("rSource", "Data Source",
                             choices = c("None",
                                         "CloudRepository",
                                         "CloudStorage"),
                             inline = TRUE),
          shiny::uiOutput("rSourceDyn"),
          shiny::br()
        )
      ),
      miniUI::miniTabPanel("plumber API", icon = shiny::icon("wrench"),
        miniUI::miniContentPanel(
          shiny::helpText("Configure arguments passed to cr_deploy_run()"),
          shiny::textInput("apiFile",
                           label = "Select folder with api.R file",
                           placeholder = "plumber/"),
          shiny::helpText("Working dir: ", getwd()),
          shiny::textInput("apiImage", label = "Docker image to build",
                           placeholder = paste0("gcr.io/",
                                          cr_project_get(),
                                          "/your-r-api")),
          shiny::br()
        )
      ),
      miniUI::miniTabPanel("Dockerfile", icon = shiny::icon("docker"),
        miniUI::miniContentPanel(
          shiny::textOutput("wd"),
          shiny::helpText("Configure arguments passed to cr_deploy_docker()"),
          shiny::textInput("dockerFile",
                           label = "Select folder with Dockerfile",
                           placeholder = "docker/"),
          shiny::helpText("Working dir: ", getwd()),
          shiny::textInput("dockerImage", label = "Edit docker basename",
                             placeholder = "my-image"),
          shiny::textInput("dockerProject", label = "GCP project",
                           value = cr_project_get()),
          shiny::textInput("dockerTag", label = "Docker tag",
                           value = "$BUILD_ID"),
          shiny::helpText(shiny::textOutput("dockerGCRIO"))
          )
      )
    )
  )

  server <- function(input, output, session) {

    output$dockerGCRIO <- shiny::renderText({
      image_name_helper(dockerImage = input$dockerImage,
                        dockerFile = input$dockerFile,
                        dockerProject = input$dockerProject,
                        dockerTag = input$dockerTag)
    })

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

      if(input$apiFile != ""){

        folder <- input$apiFile

        shiny::stopApp(
          cr_deploy_run(folder, image_name = input$apiImage)
        )
      }

      if(input$dockerFile != ""){

        folder <- input$dockerFile

        image_name <- image_name_helper(
          dockerImage = input$dockerImage,
          dockerFile = input$dockerFile,
          dockerProject = input$dockerProject,
          dockerTag = NULL)

        shiny::stopApp(
          cr_deploy_docker(folder,
                           image_name = image_name,
                           tag = input$dockerTag)
          )
      }

      shiny::stopApp()

    })
  }

  viewer <- shiny::paneViewer()
  shiny::runGadget(ui, server, viewer = viewer)

}

#' Launch the googleCloudRunner deployment RStudio gadget
#'
#' You can assign a hotkey to the addin via Tools > Addins > Browse Addins > Keyboard shortcuts.  CTRL+SHIFT+D is a suggested hotkey.
#' @import assertthat
#' @export
cr_deploy_gadget <- function(){

  assert_that(
    cr_project_get() != "",
    cr_bucket_get() != "",
    cr_region_get() != "",
    Sys.getenv("GCE_AUTH_FILE") != ""
  )

  # if invoked when the library is not loaded
  if(!googleAuthR::gar_has_token()){
    googleAuthR::gar_attach_auto_auth(
      "https://www.googleapis.com/auth/cloud-platform",
      environment_var = "GCE_AUTH_FILE")
  }

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
    miniUI::gadgetTitleBar("googleCloudRunner Deploy"),
    miniUI::miniTabstripPanel(between = miniUI::miniButtonBlock(
      shiny::numericInput("rTimeout",
                         label = "Timeout",
                         value = 600,
                         min = 100,
                         max = 3600, width = "100px"),
      shiny::textInput("dockerProject", label = "projectId",
                       value = cr_project_get()),
      shiny::column(width = 6,
        shiny::h5("Logging"),
        shiny::checkboxInput("interactive", "Launch logs in browser", value = TRUE),
        shiny::br()
      )

      ),
      miniUI::miniTabPanel("R script", icon = shiny::icon("r-project"),
        miniUI::miniContentPanel(
          shiny::h2("Configure cr_deploy_r()"),
          shiny::fileInput("rFile",
                           "Select R File",
                           accept = c(".R",".r")),
          shiny::textInput("rSchedule", label = "cron Schedule",
                           value = "15 8 * * *"),
          shiny::helpText("Set schedule to empty to run now"),
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
          shiny::h2("Configure cr_deploy_plumber()"),
          shiny::textInput("apiFile",
            label = "Select folder with api.R file and Dockerfile",
            placeholder = "plumber/"),
          shiny::helpText("Working dir: ", getwd()),
          shiny::textInput("apiDockerfile",
             label = "Dockerfile to build from",
             value = ""),
          shiny::helpText("Leave Dockerfile blank to attempt autodetection"),
          # shiny::textInput("apiName", label = "Cloud Run service name",
          #                  placeholder = "api-name"),
          shiny::textInput("apiImage",
            label = "Edit docker basename",
            placeholder = "my-image"),
          shiny::textInput("apiTag", label = "Docker tag",
                           value = "$BUILD_ID"),
          shiny::helpText(shiny::textOutput("apiGCRIO"))
        )
      ),
      miniUI::miniTabPanel("Dockerfile", icon = shiny::icon("docker"),
        miniUI::miniContentPanel(
          shiny::h2("Configure cr_deploy_docker()"),
          shiny::textInput("dockerFile",
                           label = "Select folder with Dockerfile",
                           placeholder = "docker/"),
          shiny::helpText("Working dir: ", getwd()),
          shiny::textInput("dockerImage", label = "Edit docker basename",
                             placeholder = "my-image"),
          shiny::textInput("dockerTag", label = "Docker tag",
                           value = "$BUILD_ID"),
          shiny::helpText(shiny::textOutput("dockerGCRIO")),
          shiny::checkboxInput("kaniko_cache", "Kaniko Cache", value = TRUE)
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

    output$apiGCRIO <- shiny::renderText({
      image_name_helper(dockerImage = input$apiImage,
                        dockerFile = input$apiFile,
                        dockerProject = input$dockerProject,
                        dockerTag = input$apiTag)
    })

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

        image_split <- strsplit(input$rImage, "/")[[1]]

        shiny::stopApp(
          cr_deploy_r(the_file$datapath,
                      schedule = if(input$rSchedule =="") NULL else input$rSchedule,
                      source = source,
                      run_name = input$name,
                      r_image = image_split[[2]],
                      prefix = paste0(image_split[[1]],"/"),
                      timeout = input$rTimeout,
                      launch_browser=input$interactive)
        )
      }

      if(input$apiFile != ""){

        folder <- input$apiFile

        image_name <- image_name_helper(
          dockerImage = input$apiImage,
          dockerFile = input$apiFile,
          dockerProject = input$dockerProject,
          dockerTag = NULL)

        if(input$apiDockerfile == ""){
          dockerfile <- NULL
        } else {
          dockerfile <- input$apiDockerfile
        }

        shiny::stopApp(
          cr_deploy_plumber(folder,
                        # remote = apiName,
                        dockerfile = dockerfile,
                        image_name = image_name,
                        tag = input$apiTag,
                        launch_browser=input$interactive)
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
                           tag = input$dockerTag,
                           launch_browser=input$interactive,
                           kaniko_cache=input$kaniko_cache)
          )
      }

      shiny::stopApp()

    })
  }

  viewer <- shiny::paneViewer()
  shiny::runGadget(ui, server, viewer = viewer)

}

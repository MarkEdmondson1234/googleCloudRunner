cr_deploy_gadget <- function(){

  ui <- miniUI::miniPage(
    miniUI::gadgetTitleBar("googleCloudRunner Deploy"),
    miniUI::miniTabstripPanel(
      miniUI::miniTabPanel("R script", icon = shiny::icon("r-project"),
        miniUI::miniContentPanel(
          shiny::fileInput("rFile",
                           "Select R File",
                           accept = c(".R",".r"))
        )
      ),
      miniUI::miniTabPanel("plumber API", icon = shiny::icon("wrench"),
        miniUI::miniContentPanel(
          shiny::fileInput("apiFolder",
                           "Select folder with plumber api.R file",
                           accept = c(".R",".r")),
          shiny::textInput("apiImage",
                           label = "gcr.io image name",
                           placeholder = paste0("gcr.io/",
                                                cr_project_get(),
                                                "/my-image"))
        )
      ),
      miniUI::miniTabPanel("Dockerfile", icon = shiny::icon("docker"),
                           miniUI::miniContentPanel(
                             shiny::fileInput("dockerFolder",
                                              "Select folder with Dockerfile"),
                             shiny::textInput("dockerImage",
                                              label = "gcr.io image name",
                                              placeholder = paste0("gcr.io/",
                                                                   cr_project_get(),
                                                                   "/my-image"))
                           )
      )
    )

  )

  server <- function(input, output, session) {

    ## Your reactive logic goes here.


    shiny::observeEvent(input$done, {

      shiny::stopApp()
    })
  }

  viewer <- shiny::paneViewer()
  shiny::runGadget(ui, server, viewer = viewer)

}

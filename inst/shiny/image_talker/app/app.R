Sys.setenv(GL_AUTH="auth.json")
Sys.setenv(GCV_AUTH_FILE="auth.json")

library(shiny)
library(googleAuthR)
library(googleLanguageR)
library(googleCloudVisionR)
library(shinythemes)
library(shinydashboard)

ui <- navbarPage(title = "Image Talker",
                 windowTitle="Turn images into speech using machine learning",
                 theme = shinytheme("sandstone"),
                 footer = helpText("Demo via MarkEdmondson1234/googleCloudRunner"),
                 tabPanel(title = "Talking Images",
                          sidebarLayout(
                            sidebarPanel(
                              helpText("Upload an image, have it spoken back to you"),
                              radioButtons("input_choice", "Where is the image?",
                                           choices = c("URL","Upload"), inline = TRUE),

                              uiOutput("input_ui"),
                              actionButton("do_image", "Get/Change Image"),
                              br()
                            ),
                            mainPanel(
                              uiOutput("show_image"),
                              br()

                            ))
                 ),
                 tabPanel(title = "Examples",
                 )
)

server <- function(input, output, session){

  output$input_ui <- renderUI({
    if(input$input_choice == "Upload"){
      fileInput("image_input", "Upload an image",
                accept = c("jpeg","png","gif"))
    } else {
      textInput("image_input", label = "Paste in URL to image",
                value = "https://bit.ly/2IhUzdE")
    }

  })

  image_source <- eventReactive(input$do_image, {
    if(input$input_choice == "Upload"){
      message("An uploaded image")
      if(is.null(input$image_input$datapath)) return(NULL)

      # 2MB limit
      if(file.info(input$image_input$datapath)$size > 2000000){
        stop("Image is too large - limit to under 2MB", call. = FALSE)
      }

      if(is.null(input$image_input$datapath)) return(NULL)

      # copy to www folder
      src <-  tempfile("img","www")
      file.copy(input$image_input$datapath, src)
    } else {
      message("A URL to copy")
      # download to temp file
      tmp <- tempfile()
      download.file(input$image_input, tmp)
      src <- tmp
    }

    src

  })

  output$show_image <- renderUI({
    req(image_source())

    message("image_source(): ", image_source())
    if(input$input_choice == "Upload"){
      src <- gsub("www/","",image_source())
    } else {
      src <- input$image_input
    }

    if(!is.null(input$input_choice) &&
       input$input_choice == "Upload" &&
       !is.character(input$image_input) &&
       is.null(input$image_input$datapath)){
      return(
        shinydashboard::box(
          title = "Upload an image",
          background = "olive",
          width = 12,
          br()
        )
      )
    }

    shinydashboard::box(
      title = isolate(input$say_me),
      background = "olive",
      width = 12,
      fluidRow(
            column(width = 8,
                   tags$img(src=src, width="100%", height="100%")
            ),
            column(width = 4,
                   actionButton("do_apis", "Speak this image"),
                   textInput("override_label","Override image label" ,
                             placeholder = "Provide your own image label to talk"),
                   uiOutput("image_labels")


            )),
        gl_talk_shinyUI("image_talk")
      )

  })


  annotations <- reactive({
    req(image_source())

    message("upload:", image_source())
    message("Calling vision API")
    gcv_get_image_annotations(
      image_source(),
      feature = "LABEL_DETECTION",
      maxNumResults = 5
    )

  })

  output$image_labels <- renderUI({
    req(annotations())

    choices <- annotations()$description

    if(!is.null(input$override_label) && input$override_label != ""){
      message("User provided label")
      choices <- c(input$override_label, choices)
    }

    radioButtons("say_me", "Choose what to say" ,
                 choices = choices)
  })

  talk_me <- eventReactive(input$do_apis, {
    req(input$say_me)
    input$say_me
  })

  output$big_text <- renderText({
    req(input$say_me)
    input$say_me
  })

  callModule(gl_talk_shiny, "image_talk",
             transcript = talk_me, name = "en-GB-Wavenet-A")


}

shinyApp(ui = ui, server = server)


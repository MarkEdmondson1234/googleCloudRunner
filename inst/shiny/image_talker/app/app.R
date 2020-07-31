library(shiny)
library(googleAuthR)
library(googleLanguageR)
library(googleCloudVisionR)
library(imager)

ui <- fluidPage(
  helpText("Upload an image, have it spoken back to you"),
  radioButtons("input_choice", "Where is the image?",
              choices = c("Upload","URL"), inline = TRUE),
  selectInput("voice", "What voice do you want?",
              choices = c(`Alison (GB)` = "en-GB-Wavenet-F",
                          `Sofia (DK)` = "da-DK-Wavenet-A",
                          `Frederik (DK)` = "da-DK-Wavenet-C",
                          `Lise (DK)` = "da-DK-Wavenet-D",
                          `Bruce (AU)` = "en-AU-Wavenet-B",
                          `Shelia (AU)`= "en-AU-Wavenet-A",
                          `Sue (GB)` = "en-GB-Wavenet-A",
                          `Simon (GB)` = "en-GB-Wavenet-B",
                          `Tiffany (GB)` = "en-GB-Wavenet-C",
                          `Nigel (GB)` = "en-GB-Wavenet-D")),
  uiOutput("input_ui"),
  actionButton("do_image", "Get/Change Image"),
  uiOutput("show_image"),
  uiOutput("image_labels"),
  h2(textOutput("big_text")),
  gl_talk_shinyUI("image_talk"),
  br(),
  tags$hr(),
  h4("Debug"),
  tableOutput("image_text")
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

    tagList(
      tags$img(src=src, width="500", height="500"),
      textInput("override_label","Override image label" ,
                placeholder = "Provide your own image label to talk"),
      actionButton("do_apis", "Speak this image"),
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
    message("The voice:", input$voice)
    input$say_me
  })

  output$big_text <- renderText({
    req(talk_me())
    talk_me()
  })

  callModule(gl_talk_shiny, "image_talk",
             transcript = talk_me, name = input$voice)

}

shinyApp(ui = ui, server = server)


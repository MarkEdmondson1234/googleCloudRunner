library(shiny)
library(googleAuthR)
library(googleLanguageR)
library(googleCloudVisionR)

ui <- fluidPage(
  helpText("Upload an image, have it spoken back to you"),
  selectInput("input_choice", "Where to fetch the image?",
              choices = c("Upload","URL")),
  uiOutput("input_ui"),
  actionButton("do_image", "Get Image"),
  uiOutput("show_image"),
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

    message(image_source())
    if(input$input_choice == "Upload"){
      src <- gsub("www/","",image_source())
    } else {
      src <- input$image_input
    }

    tagList(
      tags$img(src=src, width="500", height="500"),
      actionButton("do_apis", "Call APIs")
      )

  })


  annotations <- eventReactive(input$do_apis, {
    req(image_source())

    message("upload:", image_source())
    gcv_get_image_annotations(
      image_source(),
      feature = "LABEL_DETECTION",
      maxNumResults = 5
    )

  })

  output$image_text <- renderTable({
    req(annotations())

    annotations()[, c("description","score", "topicality")]
  })

  talk_me <- reactive({
    req(annotations())
    annotations()$description[[1]]
  })

  output$big_text <- renderText({
    req(talk_me())
    talk_me()
  })

  callModule(gl_talk_shiny, "image_talk",
             transcript = talk_me)

}

shinyApp(ui = ui, server = server)


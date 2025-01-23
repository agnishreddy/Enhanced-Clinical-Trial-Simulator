library(dplyr)
library(shiny)
library(ggplot2)

# UI
ui <- fluidPage(
  titlePanel("Enhanced Clinical Trial Simulator"),
  
  sidebarLayout(
    sidebarPanel(
      sliderInput("sampleSize", "Sample Size per Group:", 
                  min = 10, max = 500, value = 50, step = 10),
      numericInput("effectSize", "Treatment Effect Size (Mean Difference):", 
                   value = 2, step = 0.1),
      numericInput("sd", "Standard Deviation:", 
                   value = 1, step = 0.1),
      sliderInput("alpha", "Significance Level:", 
                  min = 0.01, max = 0.1, value = 0.05, step = 0.01),
      actionButton("simulate", "Run Simulation"),
      hr(),
      downloadButton("downloadData", "Download Simulated Data")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Results", 
                 verbatimTextOutput("testResults"),
                 plotOutput("dataPlot")),
        tabPanel("Power Analysis", 
                 plotOutput("powerPlot"),
                 verbatimTextOutput("powerResults")),
        tabPanel("Help", 
                 includeMarkdown("help.md"))
      )
    )
  )
)

# Server
server <- function(input, output) {
  # Reactive expression to generate data and perform the t-test
  simResults <- eventReactive(input$simulate, {
    n <- input$sampleSize
    effect <- input$effectSize
    sd <- input$sd
    alpha <- input$alpha
    
    # Generate random data
    control <- rnorm(n, mean = 0, sd = sd)
    treatment <- rnorm(n, mean = effect, sd = sd)
    
    # Perform t-test
    ttest <- t.test(treatment, control)
    
    list(data = data.frame(
      Group = rep(c("Control", "Treatment"), each = n),
      Value = c(control, treatment)
    ),
    pValue = ttest$p.value,
    confInt = ttest$conf.int,
    meanDiff = ttest$estimate[2] - ttest$estimate[1])
  })
  
  # Display test results
  output$testResults <- renderPrint({
    res <- simResults()
    cat("P-Value:", format(res$pValue, digits = 3), "\n")
    cat("Confidence Interval:", paste(round(res$confInt, 2), collapse = " to "), "\n")
    cat("Mean Difference:", round(res$meanDiff, 2), "\n")
  })
  
  # Plot data
  output$dataPlot <- renderPlot({
    res <- simResults()
    ggplot(res$data, aes(x = Group, y = Value, fill = Group)) +
      geom_violin(trim = FALSE, alpha = 0.6) +
      geom_boxplot(width = 0.2, position = position_dodge(0.9)) +
      geom_jitter(width = 0.1, alpha = 0.5) +
      theme_minimal() +
      labs(title = "Simulated Clinical Trial Data",
           x = "Group", y = "Value")
  })
  
  # Power analysis
  output$powerPlot <- renderPlot({
    effectSizes <- seq(0.1, 3, by = 0.1)
    powers <- sapply(effectSizes, function(effect) {
      power.t.test(n = input$sampleSize, 
                   delta = effect, 
                   sd = input$sd, 
                   sig.level = input$alpha, 
                   type = "two.sample")$power
    })
    
    data.frame(EffectSize = effectSizes, Power = powers) %>% 
      ggplot(aes(x = EffectSize, y = Power)) +
      geom_line(color = "blue", size = 1) +
      geom_hline(yintercept = 0.8, linetype = "dashed", color = "red") +
      theme_minimal() +
      labs(title = "Power Analysis",
           x = "Effect Size", y = "Power")
  })
  
  output$powerResults <- renderPrint({
    cat("Power analysis calculates the probability of detecting a true effect given the sample size, effect size, and significance level.\n")
    cat("A power of 0.8 (80%) is typically considered adequate.\n")
  })
  
  # Download simulated data
  output$downloadData <- downloadHandler(
    filename = function() {
      paste("simulated_data", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      write.csv(simResults()$data, file, row.names = FALSE)
    }
  )
}

# Run the app
shinyApp(ui = ui, server = server)

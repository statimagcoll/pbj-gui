runPBJ <- function(launch.browser = interactive(), study = NULL) {
  app <- App$new(study)
  server <- httpuv::startServer("127.0.0.1", 37212, app)
  url <- paste0("http://localhost:37212/?token=", app$token)
  cat("Running on ", url, "\n", sep = "", file = stderr())

  if (launch.browser) {
    browseURL(url)
  }

  if (!interactive()) {
    while(TRUE) {
      httpuv::service()
    }
    server$stop()
  }
}
